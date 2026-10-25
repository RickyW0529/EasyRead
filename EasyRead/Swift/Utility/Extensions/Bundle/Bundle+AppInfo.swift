//
//  Bundle+AppInfo.swift
//  EasyRead
//
//  Created by phlpsong on 2024/1/18.
//  Copyright © 2024 izual. All rights reserved.
//

import Foundation

extension Bundle {
    var applicationName: String {
        if let displayName: String = object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
            return displayName
        } else if let name: String = object(forInfoDictionaryKey: "CFBundleName") as? String {
            return name
        }
        if let executableURL {
            return executableURL.deletingLastPathComponent().lastPathComponent
        }
        return ""
    }
}
