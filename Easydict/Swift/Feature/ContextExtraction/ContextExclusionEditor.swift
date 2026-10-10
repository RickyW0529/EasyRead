//
//  ContextExclusionEditor.swift
//  Easydict
//
//  Created by wangruiqi on 2026/10/10.
//  Copyright © 2026 izual. All rights reserved.
//

import Defaults
import SwiftUI

// MARK: - ContextExclusionViewModel

/// Manages the list of apps the user excluded from reading-context
/// extraction (EasyRead Phase 2). Bundle ids are persisted in Defaults and
/// read by `AXContextExtractor` as the user-managed privacy boundary.
private class ContextExclusionViewModel: ObservableObject {
    // MARK: Lifecycle

    init() {
        fetchExcludedApps()
    }

    // MARK: Internal

    @Published var excludedBundleIDs: [String] = []
    @Published var selectedBundleIDs: Set<String> = []
    @Published var isShowImportErrorAlert = false

    @Published var isImporting = false {
        didSet {
            // https://github.com/tisfeng/Easydict/issues/346
            MyConfiguration.shared.disabledAutoSelect = isImporting
        }
    }

    func fetchExcludedApps() {
        excludedBundleIDs = Defaults[.contextExtractionExcludedApps]
    }

    func saveExcludedApps() {
        Defaults[.contextExtractionExcludedApps] = excludedBundleIDs
    }

    func removeExcludedApps() {
        excludedBundleIDs = excludedBundleIDs.filter { !selectedBundleIDs.contains($0) }
        saveExcludedApps()
        selectedBundleIDs = []
    }

    func newAppURLsSelected(from urls: [URL]) {
        for url in urls {
            let gotAccess = url.startAccessingSecurityScopedResource()
            if !gotAccess { continue }
            appendNewExcludedApp(for: url)
            url.stopAccessingSecurityScopedResource()
        }
    }

    func appendNewExcludedApp(for url: URL) {
        guard let bundleID = Bundle(url: url)?.bundleIdentifier,
              !bundleID.isEmpty,
              !excludedBundleIDs.contains(bundleID) else { return }
        excludedBundleIDs.append(bundleID)
        saveExcludedApps()
    }
}

// MARK: - ContextExclusionEditor

/// Editor for the app list that is never read for reading context.
struct ContextExclusionEditor: View {
    // MARK: Internal

    var listToolbar: some View {
        ContextExclusionToolbar()
    }

    var appListView: some View {
        List(selection: $viewModel.selectedBundleIDs) {
            ForEach(viewModel.excludedBundleIDs, id: \.self) { bundleID in
                ContextExclusionItemView(bundleID: bundleID)
                    .tag(bundleID)
            }
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollIndicators(.never)
        .frame(height: 90)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("context_extraction_excluded_apps")

            VStack(spacing: 0) {
                appListView
                listToolbar
            }
            .borderedCard()
            .onTapGesture {
                viewModel.selectedBundleIDs = []
            }

            Text("context_extraction_excluded_apps_hint")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .environmentObject(viewModel)
        .fileImporter(
            isPresented: $viewModel.isImporting,
            allowedContentTypes: [.application],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case let .success(urls):
                viewModel.newAppURLsSelected(from: urls)
            case let .failure(error):
                logError("fileImporter error: \(error)")
                viewModel.isShowImportErrorAlert.toggle()
            }
        }
        .alert(isPresented: $viewModel.isShowImportErrorAlert) {
            Alert(
                title: Text(verbatim: ""),
                message: Text("setting.disabled.import_app_error.message"),
                dismissButton: .default(Text("ok"))
            )
        }
    }

    // MARK: Private

    @StateObject private var viewModel = ContextExclusionViewModel()
}

// MARK: - ContextExclusionToolbar

private struct ContextExclusionToolbar: View {
    // MARK: Internal

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                ContextExclusionListButton(systemName: "plus") {
                    viewModel.isImporting.toggle()
                }
                .disabled(false)
                Divider()
                    .padding(.vertical, 1)
                ContextExclusionListButton(systemName: "minus") {
                    viewModel.removeExcludedApps()
                }
                .disabled(viewModel.selectedBundleIDs.isEmpty)
                Spacer()
            }
            .padding(2)
        }
        .frame(height: 28)
        .background(Color("add_minus_bg_color"))
    }

    // MARK: Private

    @EnvironmentObject private var viewModel: ContextExclusionViewModel
}

// MARK: - ContextExclusionListButton

private struct ContextExclusionListButton: View {
    // MARK: Internal

    var systemName: String
    var action: () -> ()

    var body: some View {
        Button(action: {
            action()
        }) {
            Image(systemName: systemName)
                .resizable()
                .scaledToFit()
                .frame(width: 10, height: 10)
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
                .foregroundStyle(isEnabled ? Color(.secondaryLabelColor) : Color(.tertiaryLabelColor))
                .font(.system(size: 14, weight: .semibold))
        }
        .buttonStyle(BorderlessButtonStyle())
    }

    // MARK: Private

    @Environment(\.isEnabled) private var isEnabled
}

// MARK: - ContextExclusionItemView

private struct ContextExclusionItemView: View {
    // MARK: Lifecycle

    init(bundleID: String) {
        _itemViewModel = StateObject(wrappedValue: ExcludedAppItemViewModel(bundleID: bundleID))
    }

    // MARK: Internal

    var body: some View {
        HStack(alignment: .center) {
            Image(nsImage: itemViewModel.appIcon)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)

            Text(itemViewModel.appName)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .padding(.vertical, 4)
        .padding(.leading, 6)
    }

    // MARK: Private

    @StateObject private var itemViewModel: ExcludedAppItemViewModel
}

// MARK: - ExcludedAppItemViewModel

private class ExcludedAppItemViewModel: ObservableObject {
    // MARK: Lifecycle

    init(bundleID: String) {
        self.bundleID = bundleID
        resolveAppBundleInfo()
    }

    // MARK: Internal

    @Published var appIcon = NSImage()

    @Published var appName = ""

    let bundleID: String

    func resolveAppBundleInfo() {
        let workspace = NSWorkspace.shared
        guard let appURL = workspace.urlForApplication(withBundleIdentifier: bundleID) else {
            // The app is not installed anymore; keep the entry and show its
            // bundle id so the exclusion stays meaningful.
            appName = bundleID
            return
        }

        appIcon = workspace.icon(forFile: appURL.path(percentEncoded: false))

        if let bundle = Bundle(url: appURL), !bundle.applicationName.isEmpty {
            appName = bundle.applicationName
        } else {
            appName = bundleID
        }
    }
}

#Preview {
    ContextExclusionEditor()
        .padding()
        .frame(width: 400)
}
