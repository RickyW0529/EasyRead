//
//  SystemUtility+Selection.swift
//  Easydict
//
//  Created by tisfeng on 2025/9/9.
//  Copyright © 2025 izual. All rights reserved.
//

import Foundation
import SelectedTextKit

extension SystemUtility {
    @objc
    public func getSelectedText(strategy: TextStrategy) async throws -> String? {
        guard !AXContextExtractor.shouldBlockCurrentSelection() else { return nil }
        return try await selectedTextManager.getSelectedText(strategy: strategy)
    }
}
