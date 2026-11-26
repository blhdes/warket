import SwiftUI

/// A message a screen shows in a system alert, such as a failed delete.
struct ScreenAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

extension View {
    /// Shows the alert while `alert` is set and clears it when dismissed.
    func screenAlert(_ alert: Binding<ScreenAlert?>) -> some View {
        self.alert(
            alert.wrappedValue?.title ?? "",
            isPresented: Binding(
                get: { alert.wrappedValue != nil },
                set: { if !$0 { alert.wrappedValue = nil } }
            ),
            presenting: alert.wrappedValue
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { item in
            Text(item.message)
        }
    }
}
