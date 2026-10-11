//
//  PrivacyTab.swift
//  Easydict
//
//  Created by Kyle on 2023/10/30.
//  Copyright © 2023 izual. All rights reserved.
//

import Defaults
import SwiftUI

struct PrivacyTab: View {
    // MARK: Internal

    var body: some View {
        Form {
            Section {
                Text("privacy_statement_content")
                    .font(.body)
                    .multilineTextAlignment(.leading)
            } header: {
                Text("privacy_statement")
            }
            Section {
                HStack {
                    Text("crash_log")
                    Toggle("allow_collect_crash_log", isOn: $allowCollectCrashLog)
                }
                HStack {
                    Text("analytics")
                    Toggle("allow_collect_analytics", isOn: $allowCollectAnalytics)
                }
            }
            Section {
                HStack {
                    Text("reading_context")
                    Toggle("enable_context_extraction", isOn: $enableContextExtraction)
                }
                Text("context_extraction_explanation")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ContextExclusionEditor()
                Toggle("reading.history.enable", isOn: $enableReadingHistory)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: Private

    @Default(.allowCrashLog) private var allowCollectCrashLog
    @Default(.allowAnalytics) private var allowCollectAnalytics
    @Default(.enableReadingHistory) private var enableReadingHistory
    @Default(.enableContextExtraction) private var enableContextExtraction
}

#Preview {
    PrivacyTab()
}
