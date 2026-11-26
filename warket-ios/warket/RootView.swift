import SwiftUI

/// Auth gate: shows Unlock until a vault is open, then the Lists screen.
/// Auto-resumes a remembered session on launch (handled in `Session.init`).
struct RootView: View {
    @State private var session = Session()

    var body: some View {
        gated
            .environment(session)
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
    }
}
