//
//  DeepSeekChatError+QueryError.swift
//  EasyRead
//
//  Created by wangruiqi on 2026/10/10.
//  Copyright © 2026 izual. All rights reserved.
//

import EasyReadKit
import Foundation

// MARK: - DeepSeekChatError + QueryError

extension DeepSeekChatError {
    /// Maps the transport-level taxonomy onto EasyRead's `QueryError` with a
    /// localized, user-actionable message per failure class (spec 4.4 and the
    /// degradation matrix in section 11). The API key never appears in any
    /// of these messages.
    var queryError: QueryError {
        switch self {
        case .missingAPIKey:
            // Reuses the shared "missing secret key" wording.
            QueryError(type: .missingSecretKey)
        case .invalidAPIKey:
            QueryError(type: .api, message: String(localized: "deepseek.error.invalid_api_key"))
        case .forbidden:
            QueryError(type: .api, message: String(localized: "deepseek.error.forbidden"))
        case .insufficientBalance:
            QueryError(type: .api, message: String(localized: "deepseek.error.insufficient_balance"))
        case .rateLimited:
            QueryError(type: .api, message: String(localized: "deepseek.error.rate_limited"))
        case .server, .unexpectedStatus:
            QueryError(type: .api, message: String(localized: "deepseek.error.server"))
        case .network:
            QueryError(type: .api, message: String(localized: "deepseek.error.network"))
        case .timeout:
            // The shared timeout wording already says everything needed.
            QueryError(type: .timeout)
        case .invalidResponse:
            QueryError(type: .api, message: String(localized: "deepseek.error.invalid_response"))
        case .truncatedResponse:
            QueryError(type: .api, message: String(localized: "deepseek.error.truncated"))
        case .cancelled:
            QueryError(type: .api, message: String(localized: "deepseek.error.cancelled"))
        }
    }
}
