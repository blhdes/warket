import SwiftUI

/// The only place that checks the iOS version (rule R18).
extension View {
    /// iOS 27: swiping down a sheet with unsaved changes asks first. iOS 26: the swipe is blocked
    /// while there are changes. The ✕ button closes without asking on both.
    @ViewBuilder
    func confirmDiscard(when hasChanges: Bool) -> some View {
        if #available(iOS 27.0, *) {
            dismissalConfirmationDialog("Discard Changes?", shouldPresent: hasChanges) {
                // The system closes the sheet itself after a destructive button, so it needs no
                // action: calling dismiss() here as well would close a second time.
                Button("Discard Changes", role: .destructive) {}
            }
        } else {
            interactiveDismissDisabled(hasChanges)
        }
    }
}
