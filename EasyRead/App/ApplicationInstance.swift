//
//  ApplicationInstance.swift
//  EasyRead
//

import AppKit
import Darwin

/// Owns the process-lifetime lock before any UI or global input handlers start.
enum ApplicationInstance {
    // MARK: Internal

    static func acquire() -> Bool {
        // XCTest launches a host process independently of the user's running app.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil {
            return true
        }

        guard let identifier = Bundle.main.bundleIdentifier else { return false }

        // Also recognize older versions which do not yet take the lock.
        if let running = existingApplication(identifier: identifier) {
            notifyExistingApplication(running, identifier: identifier)
            return false
        }

        let directory = AppPathManager.current.appSupportDirectory
        do {
            try AppPathManager.current.ensureDirectoryExists(at: directory)
        } catch {
            NSLog("Cannot create application instance directory: %@", error.localizedDescription)
            return false
        }

        let path = directory.appendingPathComponent("application.lock").path
        let descriptor = open(path, O_CREAT | O_RDWR | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else {
            NSLog("Cannot open application instance lock: %d", errno)
            return false
        }
        // Subscribe before claiming the lock so a simultaneous launch can hand
        // off its arguments as soon as it observes a lock owner.
        observeLaunchRequests(identifier: identifier)
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            notifyExistingApplication(existingApplication(identifier: identifier), identifier: identifier)
            return false
        }

        // Never unlink this file: concurrent launches must lock the same inode.
        // The OS releases the lock even after a crash; the descriptor must stay open.
        lockDescriptor = descriptor
        return true
    }

    // MARK: Private

    private static var lockDescriptor: Int32 = -1
    private static var launchObserver: NSObjectProtocol?

    private static func observeLaunchRequests(identifier: String) {
        launchObserver = DistributedNotificationCenter.default().addObserver(
            forName: .init("\(identifier).reopen"), object: identifier, queue: .main
        ) { notification in
            guard lockDescriptor >= 0,
                  let arguments = notification.userInfo?["arguments"] as? [String] else { return }
            if arguments.count > 1 {
                parseApplicationArguments(arguments)
            } else {
                EZWindowManager.shared().showMainWindowIfNeeded()
            }
        }
    }

    private static func notifyExistingApplication(_ application: NSRunningApplication?, identifier: String) {
        DistributedNotificationCenter.default().postNotificationName(
            .init("\(identifier).reopen"), object: identifier,
            userInfo: ["arguments": ProcessInfo.processInfo.arguments], deliverImmediately: true
        )
        application?.activate(options: [.activateIgnoringOtherApps])
    }

    private static func existingApplication(identifier: String) -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: identifier).first {
            !$0.isEqual(NSRunningApplication.current) && !$0.isTerminated && $0.isFinishedLaunching
        }
    }
}
