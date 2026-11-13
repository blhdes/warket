import SwiftUI

/// Auth gate: shows Unlock until a vault is open, then the Lists screen.
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
            if let access = session.access {
                NavigationStack {
                    ListsView(access: access)
                }
                .id(access) // fresh repository if a different vault is opened
            } else {
                UnlockView()
            }
        }
        .animation(.snappy, value: session.access)
        .toastHost()
    }
}
