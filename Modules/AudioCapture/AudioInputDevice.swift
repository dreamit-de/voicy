import CoreAudio
import Foundation

/// A CoreAudio device that can capture audio. `uid` is the persistent
/// identity (stable across reboots and reconnects) and is what settings
/// store; `deviceID` is only valid for the current CoreAudio session.
public struct AudioInputDevice: Identifiable, Equatable, Hashable, Sendable {
    public let uid: String
    public let name: String
    public let deviceID: AudioDeviceID

    public var id: String { uid }

    public init(uid: String, name: String, deviceID: AudioDeviceID = kAudioObjectUnknown) {
        self.uid = uid
        self.name = name
        self.deviceID = deviceID
    }
}

/// Outcome of matching the user's microphone choice against the devices that
/// are connected right now.
public enum MicrophoneResolution: Equatable, Sendable {
    /// No explicit choice — follow the macOS default input (nil if macOS
    /// reports no default input device).
    case systemDefault(AudioInputDevice?)
    /// The chosen device is connected and will be used.
    case chosen(AudioInputDevice)
    /// The chosen device is not connected; the system default is used instead.
    /// Surfaced in the UI so the switch never happens silently.
    case fallback(missingUID: String, systemDefault: AudioInputDevice?)

    /// The device a recording would actually use.
    public var device: AudioInputDevice? {
        switch self {
        case .systemDefault(let device): return device
        case .chosen(let device): return device
        case .fallback(_, let device): return device
        }
    }

    public var isFallback: Bool {
        if case .fallback = self { return true }
        return false
    }
}

/// Pure selection logic, kept free of CoreAudio so it is unit-testable.
public enum MicrophoneSelection {
    /// Resolves the persisted choice (`preferredUID`, nil = system default)
    /// against the current device list.
    public static func resolve(
        preferredUID: String?,
        devices: [AudioInputDevice],
        systemDefaultUID: String?
    ) -> MicrophoneResolution {
        let systemDefault = systemDefaultUID.flatMap { uid in devices.first { $0.uid == uid } }
        guard let preferredUID, !preferredUID.isEmpty else {
            return .systemDefault(systemDefault)
        }
        if let chosen = devices.first(where: { $0.uid == preferredUID }) {
            return .chosen(chosen)
        }
        return .fallback(missingUID: preferredUID, systemDefault: systemDefault)
    }
}

/// Thin CoreAudio HAL wrappers: enumerate input devices and read the default
/// input. Synchronous and cheap (a handful of property reads per device).
enum CoreAudioDevices {
    private static let systemObject = AudioObjectID(kAudioObjectSystemObject)

    /// All visible devices with at least one input stream, sorted by name.
    /// Aggregate/virtual devices are kept as long as they can capture; hidden
    /// devices (e.g. private aggregates other apps create) are skipped.
    static func inputDevices() -> [AudioInputDevice] {
        var address = globalAddress(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(systemObject, &address, 0, nil, &size) == noErr, size > 0 else {
            return []
        }
        var ids = [AudioDeviceID](repeating: kAudioObjectUnknown, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(systemObject, &address, 0, nil, &size, &ids) == noErr else {
            return []
        }
        return ids
            .compactMap(device(for:))
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// UID of the current macOS default input device, nil if there is none.
    static func defaultInputUID() -> String? {
        var address = globalAddress(kAudioHardwarePropertyDefaultInputDevice)
        var deviceID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(systemObject, &address, 0, nil, &size, &deviceID) == noErr,
              deviceID != kAudioObjectUnknown else { return nil }
        return stringProperty(deviceID, kAudioDevicePropertyDeviceUID)
    }

    private static func device(for id: AudioDeviceID) -> AudioInputDevice? {
        guard hasInputStreams(id), !isHidden(id),
              let uid = stringProperty(id, kAudioDevicePropertyDeviceUID) else { return nil }
        let name = stringProperty(id, kAudioObjectPropertyName) ?? uid
        return AudioInputDevice(uid: uid, name: name, deviceID: id)
    }

    private static func hasInputStreams(_ id: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr && size > 0
    }

    private static func isHidden(_ id: AudioDeviceID) -> Bool {
        var address = globalAddress(kAudioDevicePropertyIsHidden)
        var hidden: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &hidden) == noErr else { return false }
        return hidden != 0
    }

    private static func stringProperty(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var address = globalAddress(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr,
              let value else { return nil }
        return value.takeRetainedValue() as String
    }

    static func globalAddress(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }
}

/// Watches the HAL for connected/disconnected devices and default-input
/// changes and reports the fresh device list on the main actor. Lives as long
/// as the coordinator (i.e. the app).
@MainActor
public final class AudioDeviceMonitor {
    public typealias ChangeHandler = @MainActor (_ devices: [AudioInputDevice], _ systemDefaultUID: String?) -> Void

    private var onChange: ChangeHandler?
    /// Kept so `deinit` can unregister exactly the block that was added.
    nonisolated(unsafe) private var listener: AudioObjectPropertyListenerBlock?

    public init() {}

    /// Registers the HAL listeners and delivers the current state immediately.
    /// Idempotent.
    public func start(onChange: @escaping ChangeHandler) {
        self.onChange = onChange
        if listener == nil {
            // Delivered on the main queue, so hopping onto the main actor
            // synchronously is sound.
            let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
            for var address in Self.watchedAddresses() {
                AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, block)
            }
            listener = block
        }
        refresh()
    }

    public func refresh() {
        onChange?(CoreAudioDevices.inputDevices(), CoreAudioDevices.defaultInputUID())
    }

    deinit {
        guard let listener else { return }
        for var address in Self.watchedAddresses() {
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, listener)
        }
    }

    private nonisolated static func watchedAddresses() -> [AudioObjectPropertyAddress] {
        [
            CoreAudioDevices.globalAddress(kAudioHardwarePropertyDevices),
            CoreAudioDevices.globalAddress(kAudioHardwarePropertyDefaultInputDevice),
        ]
    }
}
