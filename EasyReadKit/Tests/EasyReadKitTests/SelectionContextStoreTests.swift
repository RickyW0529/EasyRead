// Copyright © 2026 EasyRead contributors. GPL-3.0.
import Testing
@testable import EasyReadKit

@Suite struct SelectionContextStoreTests {
    @Test func olderCaptureCannotReplaceNewerSelection() {
        let store = SelectionContextStore()
        let old = SelectionSnapshot.selectionOnly(selectedText: "process", sourceBundleID: "com.reader")
        let new = SelectionSnapshot.selectionOnly(selectedText: "bank", sourceBundleID: "com.reader")
        store.store(old)
        store.store(new)
        store.completeCapture(old, selectionID: old.selectionID)
        #expect(store.snapshot(matchingSelectedText: "bank") == new)
        #expect(store.snapshot(matchingSelectedText: "process") == nil)
    }
    @Test func clearingStoreInvalidatesOutstandingCapture() {
        let store = SelectionContextStore()
        let snapshot = SelectionSnapshot.selectionOnly(selectedText: "process", sourceBundleID: nil)
        store.store(snapshot)
        store.clear()
        store.completeCapture(snapshot, selectionID: snapshot.selectionID)
        #expect(store.snapshot(matchingSelectedText: "process") == nil)
    }
    @Test func repeatedWordHasDistinctSelectionIdentity() {
        let store = SelectionContextStore()
        let old = SelectionSnapshot.selectionOnly(selectedText: "bank", sourceBundleID: nil)
        let new = SelectionSnapshot.selectionOnly(selectedText: "bank", sourceBundleID: nil)
        store.store(old)
        store.store(new)
        store.completeCapture(old, selectionID: old.selectionID)
        #expect(store.snapshot(matchingSelectedText: "bank")?.selectionID == new.selectionID)
    }
}
