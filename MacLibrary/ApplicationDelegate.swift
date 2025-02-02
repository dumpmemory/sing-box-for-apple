import AppKit
import ApplicationLibrary
import Foundation
import Libbox
import Library

open class ApplicationDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_: Notification) {
        NSLog("Here I stand")
        LibboxSetup(FilePath.sharedDirectory.relativePath, FilePath.workingDirectory.relativePath, FilePath.cacheDirectory.relativePath, false)
        let event = NSAppleEventManager.shared().currentAppleEvent
        let launchedAsLogInItem =
            event?.eventID == kAEOpenApplication &&
            event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        if !launchedAsLogInItem || !SharedPreferences.showMenuBarExtra || !SharedPreferences.menuBarExtraInBackground {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            NSApp.windows.first?.close()
        }
        Task.detached {
            do {
                try ProfileUpdateTask.setup()
                if launchedAsLogInItem {
                    if SharedPreferences.startedByUser {
                        if let profile = try await ExtensionProfile.load() {
                            try await profile.start()
                        }
                    }
                }
            } catch {
                NSLog("application setup error: \(error.localizedDescription)")
            }
        }
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        !SharedPreferences.menuBarExtraInBackground
    }

    public func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag, NSApp.activationPolicy() == .accessory {
            NSApp.setActivationPolicy(.regular)
            NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.activate()
        }
        return true
    }
}
