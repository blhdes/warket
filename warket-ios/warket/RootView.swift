import SwiftUI

/// Auth gate: shows Unlock until a vault hash exists, then the Lists screen.
/// Auto-resumes a remembered session on launch (handled in `Session.init`).
/// Also hosts the app-wide toast banner.
struct RootView: View {
    @State private var session = Session()
    @State private var toast = ToastCenter()

    var body: some View {
        gated
            .environment(session)
            .environment(toast)
    }

    private var gated: some View {
        Group {
            if let hash = session.vaultHash {
                NavigationStack {
                    ListsView(vaultHash: hash, readOnly: session.readOnly)
                }
                .id(hash) // fresh repository if a different vault is opened
            } else {
                UnlockView()
            }
        }
        .animation(.snappy, value: session.vaultHash)
        .toastHost()
    }
}
