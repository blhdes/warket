import SwiftUI

extension View {
    /// Shows "Read-only" under the navigation title of a shared vault. `isReadOnly` never changes
    /// while a screen is alive (RootView rebuilds everything when the vault changes), so the
    /// branch is stable.
    @ViewBuilder
    func readOnlySubtitle(_ isReadOnly: Bool) -> some View {
        if isReadOnly {
            navigationSubtitle("Read-only")
        } else {
            self
        }
    }
}
