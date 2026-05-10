import AVFoundation
import AppKit
import ApplicationServices
import Combine
import Foundation
import IOKit.hid
import os

public enum PermissionStatus: Equatable, Sendable {
    case granted
    case denied
    case notDetermined
}

@MainActor
public final class Permissions: ObservableObject {
    @Published public private(set) var microphone: PermissionStatus = .notDetermined
    @Published public private(set) var accessibility: PermissionStatus = .notDetermined
    @Published public private(set) var inputMonitoring: PermissionStatus = .notDetermined

    private let log = Logger(subsystem: "de.dreamit.voicy", category: "Permissions")
    nonisolated(unsafe) private var pollTask: Task<Void, Never>?

    public init() {
        refresh()
        startPolling()
    }

    deinit {
        pollTask?.cancel()
    }

    public var allGranted: Bool {
        microphone == .granted && accessibility == .granted && inputMonitoring == .granted
    }

    public func refresh() {
        microphone = currentMicrophoneStatus()
        accessibility = currentAccessibilityStatus()
        inputMonitoring = currentInputMonitoringStatus()
    }

    public func requestMicrophone() async -> PermissionStatus {
        if microphone == .granted { return .granted }
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        let status: PermissionStatus = granted ? .granted : .denied
        microphone = status
        return status
    }

    /// Triggers the system AX prompt. The actual grant happens out-of-process; the
    /// caller should poll `accessibility` afterwards.
    public func requestAccessibility() {
        let prompt = "AXTrustedCheckOptionPrompt" as CFString
        let options = [prompt: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        accessibility = currentAccessibilityStatus()
    }

    public func requestInputMonitoring() {
        let access = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        inputMonitoring = access ? .granted : currentInputMonitoringStatus()
    }

    public func openSystemSettings(for permission: Permission) {
        let urlString: String
        switch permission {
        case .microphone:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        case .accessibility:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .inputMonitoring:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        }
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    public enum Permission: Sendable {
        case microphone, accessibility, inputMonitoring
    }

    // MARK: - Private

    private func currentMicrophoneStatus() -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return .granted
        case .denied, .restricted: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    private func currentAccessibilityStatus() -> PermissionStatus {
        AXIsProcessTrusted() ? .granted : .denied
    }

    private func currentInputMonitoringStatus() -> PermissionStatus {
        let access = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        switch access {
        case kIOHIDAccessTypeGranted: return .granted
        case kIOHIDAccessTypeDenied: return .denied
        case kIOHIDAccessTypeUnknown: return .notDetermined
        default: return .notDetermined
        }
    }

    private func startPolling() {
        // System grants happen out-of-process (Settings.app). Poll lightly so the
        // UI flips green without requiring an app restart.
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await MainActor.run { self?.refresh() }
            }
        }
    }
}
