import Foundation
import ServiceManagement
import os

public enum LaunchAtLogin {
    private static let log = Logger(subsystem: "de.dreamit.voicy", category: "LaunchAtLogin")

    public static func set(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            log.error("LaunchAtLogin toggle failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    public static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
}
