//
//  Screenshot+UserDefaults.swift
//  EasyRead
//
//  Created by tisfeng on 2025/3/17.
//  Copyright © 2025 izual. All rights reserved.
//

import Foundation

// MARK: - UserDefaults Properties

extension Screenshot {
    // MARK: - UserDefaults keys

    /// Has requested permission key
    private var hasRequestedPermissionKey: String {
        migratedPreferenceKey("hasRequestedPermission")
    }

    /// Last screenshot rect key
    private var lastScreenshotRectKey: String {
        migratedPreferenceKey("lastScreenshotRect")
    }

    /// Last screen key
    private var lastScreenKey: String {
        migratedPreferenceKey("lastScreen")
    }

    /// Last screen frame key
    private var lastScreenFrameKey: String {
        migratedPreferenceKey("lastScreenFrame")
    }

    /// Moves historical preferences within this app's defaults domain without changing saved geometry.
    private func migratedPreferenceKey(_ name: String) -> String {
        let key = "easyread.screenshot.\(name)"
        let legacyKey = "easydict.screenshot.\(name)"
        let defaults = UserDefaults.standard
        if defaults.object(forKey: key) == nil, let value = defaults.object(forKey: legacyKey) {
            defaults.set(value, forKey: key)
            defaults.removeObject(forKey: legacyKey)
        }
        return key
    }

    /// Whether screen capture permission has been requested
    @objc public var hasRequestedPermission: Bool {
        get {
            UserDefaults.standard.bool(forKey: hasRequestedPermissionKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: hasRequestedPermissionKey)
        }
    }

    /// Last screenshot rectangle, persisted in UserDefaults
    @objc public var lastScreenshotRect: CGRect {
        get {
            let defaults = UserDefaults.standard
            guard let rectString = defaults.string(forKey: lastScreenshotRectKey) else {
                return .zero
            }
            return NSRectFromString(rectString)
        }
        set {
            let defaults = UserDefaults.standard
            let rectString = NSStringFromRect(newValue)
            defaults.set(rectString, forKey: lastScreenshotRectKey)
        }
    }

    @objc public var lastScreen: NSScreen? {
        get {
            let defaults = UserDefaults.standard
            guard let screenDescription = defaults.string(forKey: lastScreenKey) else {
                return nil
            }
            return NSScreen.screens.first { $0.deviceDescriptionString == screenDescription }
        }
        set {
            let defaults = UserDefaults.standard
            let screenDescription = newValue?.deviceDescriptionString
            defaults.set(screenDescription, forKey: lastScreenKey)
        }
    }

    @objc public var lastScreenFrame: NSRect {
        get {
            let defaults = UserDefaults.standard
            guard let frameString = defaults.string(forKey: lastScreenFrameKey) else {
                return .zero
            }
            return NSRectFromString(frameString)
        }
        set {
            let defaults = UserDefaults.standard
            let frameString = NSStringFromRect(newValue)
            defaults.set(frameString, forKey: lastScreenFrameKey)
        }
    }
}
