import AVFoundation
import AppKit
import ApplicationServices
import Combine
import CoreGraphics
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
    private var hasPromptedAccessibility = false

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

    public func requestAccessibility() {
        hasPromptedAccessibility = true
        let prompt = "AXTrustedCheckOptionPrompt" as CFString
        let options = [prompt: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        accessibility = currentAccessibilityStatus()
    }

    public func requestInputMonitoring() {
        // Attempting CGEventTap creation is the most reliable TCC trigger for Input
        // Monitoring — it causes macOS to add the app to the System Settings list.
        // IOHIDRequestAccess alone does not reliably do this on macOS 14+.
        let mask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)
        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, _, event, _ in Unmanaged.passUnretained(event) },
            userInfo: nil
        )
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            inputMonitoring = .granted
        } else {
            _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
            inputMonitoring = currentInputMonitoringStatus()
        }
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
        if AXIsProcessTrusted() { return .granted }
        return hasPromptedAccessibility ? .denied : .notDetermined
    }

    private func currentInputMonitoringStatus() -> PermissionStatus {
        // IOHIDAccessType bridges into Swift as a typed enum on macOS, but the exact
        // case names depend on SDK version. Compare via raw UInt32 to stay portable:
        // 0 = granted, 1 = denied, 2 = unknown.
        let access = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        switch access.rawValue {
        case 0: return .granted
        case 1: return .denied
        default: return .notDetermined
        }
    }

    private func startPolling() {
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                await MainActor.run { self?.refresh() }
            }
        }
    }
}
