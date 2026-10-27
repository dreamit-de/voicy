import AVFoundation
import AudioToolbox
import CoreAudio
import Foundation
import os
import os.lock

public protocol AudioRecorderProtocol: AnyObject, Sendable {
    /// Starts capturing from the device with `inputDeviceUID` (nil = macOS
    /// default input). Returns how the choice was resolved — including a
    /// fallback to the system default when the chosen device is missing.
    @discardableResult
    func start(inputDeviceUID: String?) async throws -> MicrophoneResolution
    func stop() async -> [Float]
    var isRecording: Bool { get }
    /// Called (on an arbitrary thread) when a running recording ends on its
    /// own — the bound device vanished or capture could not be restarted
    /// after a device reconfiguration. The recorder is stopped by then.
    func setInterruptionHandler(_ handler: @escaping @Sendable (Error) -> Void)
}

public extension AudioRecorderProtocol {
    func setInterruptionHandler(_ handler: @escaping @Sendable (Error) -> Void) {}
}

/// Captures microphone audio and resamples it to 16 kHz mono Float32 — the
/// canonical format Whisper consumes.
///
/// Every recording gets a fresh `AVAudioEngine` that is explicitly bound to
/// the resolved device. A long-lived engine keeps the input device it saw at
/// first use and does not reliably follow later default-device changes (e.g.
/// AirPods or an iPhone Continuity mic connecting), which made recordings
/// silently come from the wrong microphone.
///
/// When the bound device reconfigures mid-recording (Bluetooth headsets
/// switching to HFP once input starts, another app changing a USB mic's
/// sample rate) the engine stops itself. The recorder then rebuilds the
/// engine on the same device and keeps appending to the same buffer; if that
/// is impossible it stops and reports through the interruption handler.
public final class AudioRecorder: AudioRecorderProtocol, @unchecked Sendable {
    /// Serializes start, stop and configuration-change restarts. All mutable
    /// state below except `converter` and `buffer` is only touched on it.
    private let controlQueue = DispatchQueue(label: "de.dreamit.voicy.AudioRecorder.control")

    private var engine: AVAudioEngine?
    private var configObserver: NSObjectProtocol?
    private var recording = false
    private var boundDeviceUID: String?
    private var restartsThisRecording = 0
    private var interruptionHandler: (@Sendable (Error) -> Void)?
    private let log = Logger(subsystem: "de.dreamit.voicy", category: "AudioRecorder")

    /// Upper bound for engine rebuilds per recording, so a device that keeps
    /// reconfiguring cannot trap the recorder in a restart loop.
    private static let maxRestartsPerRecording = 5

    private let targetFormat: AVAudioFormat = {
        AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        )!
    }()

    /// Only touched from the tap thread once the tap is installed; rebuilt
    /// there whenever the delivered buffer format differs from its input.
    private var converter: AVAudioConverter?

    /// Captured PCM samples, guarded by an unfair lock that — unlike `NSLock` —
    /// is callable from `async` contexts without tripping Swift 6 strict
    /// concurrency. The lock owns the array; mutations happen inside `withLock`.
    private let buffer = OSAllocatedUnfairLock<[Float]>(initialState: [])

    public var isRecording: Bool {
        controlQueue.sync { recording }
    }

    public init() {}

    public func setInterruptionHandler(_ handler: @escaping @Sendable (Error) -> Void) {
        controlQueue.sync { interruptionHandler = handler }
    }

    @discardableResult
    public func start(inputDeviceUID: String?) async throws -> MicrophoneResolution {
        try controlQueue.sync { try startLocked(inputDeviceUID: inputDeviceUID) }
    }

    public func stop() async -> [Float] {
        controlQueue.sync { stopLocked() }
    }

    // MARK: - Control (on controlQueue)

    private func startLocked(inputDeviceUID: String?) throws -> MicrophoneResolution {
        guard !recording else {
            throw AudioRecorderError.alreadyRecording
        }

        // Resolve against the devices connected *now*, not a cached list.
        let resolution = MicrophoneSelection.resolve(
            preferredUID: inputDeviceUID,
            devices: CoreAudioDevices.inputDevices(),
            systemDefaultUID: CoreAudioDevices.defaultInputUID()
        )
        guard let device = resolution.device else {
            throw AudioRecorderError.noInputDevice
        }

        buffer.withLock { $0.removeAll(keepingCapacity: true) }
        // No tap is installed yet, so resetting the converter here cannot
        // race the tap thread; `process` builds one for the delivered format.
        converter = nil

        let engine = try launchEngine(on: device)
        self.engine = engine
        boundDeviceUID = device.uid
        restartsThisRecording = 0
        recording = true
        log.info("""
            AudioRecorder started; device=\(device.name, privacy: .public) \
            uid=\(device.uid, privacy: .public) fallback=\(resolution.isFallback, privacy: .public)
            """)
        return resolution
    }

    private func stopLocked() -> [Float] {
        guard recording else { return [] }
        if let engine { teardown(engine) }
        engine = nil
        recording = false
        boundDeviceUID = nil

        let samples = drainBuffer()
        log.info("AudioRecorder stopped; captured \(samples.count, privacy: .public) samples (\(Double(samples.count) / 16000.0, privacy: .public)s)")
        return samples
    }

    /// Runs on `controlQueue` after `AVAudioEngineConfigurationChange`. The
    /// engine has stopped itself; rebuild it on the same device (its
    /// `AudioDeviceID` may have changed, so re-resolve by UID) and keep
    /// appending to the existing buffer.
    private func handleConfigurationChange(of changed: AVAudioEngine) {
        guard recording, let current = engine, current === changed else { return }
        log.notice("Audio configuration changed during recording; restarting capture")
        teardown(current)
        engine = nil

        do {
            restartsThisRecording += 1
            guard restartsThisRecording <= Self.maxRestartsPerRecording else {
                throw AudioRecorderError.captureInterrupted
            }
            guard let uid = boundDeviceUID,
                  let device = CoreAudioDevices.inputDevices().first(where: { $0.uid == uid }) else {
                throw AudioRecorderError.deviceDisconnected
            }
            engine = try launchEngine(on: device)
            log.info("AudioRecorder restarted on uid=\(device.uid, privacy: .public) (restart \(self.restartsThisRecording, privacy: .public))")
        } catch {
            log.error("Restarting capture failed: \(error.localizedDescription, privacy: .public)")
            recording = false
            boundDeviceUID = nil
            // Nobody will call `stop()` for these samples once the UI has left
            // the recording state — drop them instead of keeping them around.
            _ = drainBuffer()
            interruptionHandler?(error)
        }
    }

    /// Builds, binds, taps and starts a fresh engine on `device`. On failure
    /// everything set up so far is torn down before the error is rethrown.
    private func launchEngine(on device: AudioInputDevice) throws -> AVAudioEngine {
        let engine = AVAudioEngine()
        let input = engine.inputNode
        try bind(device, to: input)
        alignClientFormat(of: input, deviceUID: device.uid)

        // Query the formats only after binding — they reflect the bound device.
        let inputFormat = input.inputFormat(forBus: 0)
        let outputFormat = input.outputFormat(forBus: 0)
        log.info("""
            Input formats; uid=\(device.uid, privacy: .public) \
            hardware=\(inputFormat.sampleRate, privacy: .public)Hz/\(inputFormat.channelCount, privacy: .public)ch \
            client=\(outputFormat.sampleRate, privacy: .public)Hz/\(outputFormat.channelCount, privacy: .public)ch
            """)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0,
              outputFormat.sampleRate > 0, outputFormat.channelCount > 0 else {
            throw AudioRecorderError.noInputDevice
        }
        guard AVAudioConverter(from: outputFormat, to: targetFormat) != nil else {
            throw AudioRecorderError.converterUnavailable
        }

        // `format: nil` taps in the node's own output format, so a device
        // whose format differs from what we queried can never trip the
        // format-mismatch assertion; `process` adapts the converter instead.
        input.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] pcm, _ in
            self?.process(pcm)
        }

        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: nil
        ) { [weak self, weak engine] _ in
            // Hop onto the control queue: the notification can arrive on any
            // thread, also while `stop()` is tearing the engine down.
            guard let self, let engine else { return }
            self.controlQueue.async { self.handleConfigurationChange(of: engine) }
        }

        do {
            engine.prepare()
            try engine.start()
        } catch {
            teardown(engine)
            throw error
        }
        return engine
    }

    /// Points the input node's HAL unit at `device`. Done for the system
    /// default too, so the device we log is the device we record from.
    private func bind(_ device: AudioInputDevice, to input: AVAudioInputNode) throws {
        guard let unit = input.audioUnit else {
            throw AudioRecorderError.deviceBindingFailed(kAudioUnitErr_Uninitialized)
        }
        var deviceID = device.deviceID
        let status = AudioUnitSetProperty(
            unit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else {
            log.error("Binding input device failed; uid=\(device.uid, privacy: .public) status=\(status, privacy: .public)")
            throw AudioRecorderError.deviceBindingFailed(status)
        }
    }

    /// Accessing `engine.inputNode` configures the HAL unit's client format
    /// from the *default* device. Rebinding to another device updates the
    /// hardware-side format but not necessarily that client format, and the
    /// input side of AUHAL cannot sample-rate-convert — a stale rate makes
    /// `start()` fail or mislabels buffers (pitch-shifted audio). Set the
    /// client format to the bound device's rate and channel count explicitly.
    private func alignClientFormat(of input: AVAudioInputNode, deviceUID: String) {
        let hardware = input.inputFormat(forBus: 0)
        let client = input.outputFormat(forBus: 0)
        guard hardware.sampleRate > 0, hardware.channelCount > 0,
              client.sampleRate != hardware.sampleRate || client.channelCount != hardware.channelCount,
              let unit = input.audioUnit,
              let wanted = AVAudioFormat(standardFormatWithSampleRate: hardware.sampleRate, channels: hardware.channelCount)
        else { return }

        log.notice("""
            Client format mismatch; uid=\(deviceUID, privacy: .public) \
            hardware=\(hardware.sampleRate, privacy: .public)Hz/\(hardware.channelCount, privacy: .public)ch \
            client=\(client.sampleRate, privacy: .public)Hz/\(client.channelCount, privacy: .public)ch — realigning
            """)
        var asbd = wanted.streamDescription.pointee
        let status = AudioUnitSetProperty(
            unit,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Output,
            1,
            &asbd,
            UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        )
        if status != noErr {
            // Not fatal on its own: the format validation in `launchEngine`
            // and `engine.start()` decide whether capture can proceed.
            log.error("Setting client stream format failed; uid=\(deviceUID, privacy: .public) status=\(status, privacy: .public)")
        }
    }

    private func teardown(_ engine: AVAudioEngine) {
        if let configObserver {
            NotificationCenter.default.removeObserver(configObserver)
            self.configObserver = nil
        }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }

    private func drainBuffer() -> [Float] {
        buffer.withLock { (state: inout [Float]) -> [Float] in
            let snapshot = state
            state.removeAll(keepingCapacity: false)
            return snapshot
        }
    }

    // MARK: - Tap thread

    private func process(_ inputBuffer: AVAudioPCMBuffer) {
        if converter?.inputFormat != inputBuffer.format {
            converter = AVAudioConverter(from: inputBuffer.format, to: targetFormat)
        }
        guard let converter else { return }
        let ratio = targetFormat.sampleRate / inputBuffer.format.sampleRate
        let outputCapacity = AVAudioFrameCount(Double(inputBuffer.frameLength) * ratio + 1024)
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: outputCapacity
        ) else { return }

        var consumed = false
        var error: NSError?
        let status = converter.convert(to: outputBuffer, error: &error) { _, inputStatus in
            if consumed {
                inputStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            inputStatus.pointee = .haveData
            return inputBuffer
        }

        if status == .error {
            log.error("Converter error: \(error?.localizedDescription ?? "unknown", privacy: .public)")
            return
        }

        guard let channel = outputBuffer.floatChannelData?[0] else { return }
        let frames = Int(outputBuffer.frameLength)
        if frames == 0 { return }

        buffer.withLock { state in
            state.append(contentsOf: UnsafeBufferPointer(start: channel, count: frames))
        }
    }
}

public enum AudioRecorderError: LocalizedError, Sendable {
    case noInputDevice
    case converterUnavailable
    case alreadyRecording
    case deviceBindingFailed(OSStatus)
    case deviceDisconnected
    case captureInterrupted

    public var errorDescription: String? {
        switch self {
        case .noInputDevice:
            return "Kein Mikrofon verfügbar."
        case .converterUnavailable:
            return "Audioformat des Mikrofons wird nicht unterstützt."
        case .alreadyRecording:
            return "Aufnahme läuft bereits."
        case .deviceBindingFailed(let status):
            return "Mikrofon konnte nicht aktiviert werden (Fehler \(status))."
        case .deviceDisconnected:
            return "Mikrofon wurde während der Aufnahme getrennt — Aufnahme abgebrochen."
        case .captureInterrupted:
            return "Mikrofon hat die Aufnahme unterbrochen — bitte erneut versuchen."
        }
    }
}
