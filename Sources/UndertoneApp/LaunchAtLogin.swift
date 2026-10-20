import Foundation
import os
import ServiceManagement
import UndertoneCore

/// Opening Undertone at login, as a login item the user can also see and remove in System Settings.
@MainActor
enum LaunchAtLogin {
    private static let log = Logger(subsystem: "io.github.mpdreamz.undertone", category: "login")

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Turned off in System Settings (or awaiting approval there): Undertone cannot turn it on itself.
    static var needsApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    /// Nothing Undertone keeps exists yet: no picture showing, no settings, no config file. Read once, at launch,
    /// before anything is written (main.swift reads it first).
    static let isFirstRun: Bool = {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: "pick") == nil && defaults.object(forKey: "settings") == nil
            && !FileManager.default.fileExists(atPath: Preferences.resolvedConfigURL.path)
    }()

    /// On a new install, open at login: Undertone keeps the picture set, follows the schedule and draws lock screen
    /// motion only while it runs. Done once and remembered, so turning it off stays off; upgrades from a version that
    /// left it off are not changed, and local builds never register.
    static func turnOnForNewInstall() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "loginItemOffered") else { return }
        defaults.set(true, forKey: "loginItemOffered")
        guard isFirstRun, !BuildInfo(info: Bundle.main.infoDictionary ?? [:]).isDev else { return }
        set(true)
        log.info("opened at login for a new install")
    }

    static func set(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            log.error("launch at login \(enabled): \(String(describing: error), privacy: .public)")
        }
    }
}
