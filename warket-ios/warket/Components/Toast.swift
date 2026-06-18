import SwiftUI

/// App-wide transient notifications (success / error / info). Inject one
/// `ToastCenter` at the root and call `show(_:_:)` from anywhere.
@Observable
final class ToastCenter {
    enum Style: Equatable { case success, error, info }

    struct Toast: Equatable, Identifiable {
        let id = UUID()
        let message: String
        let style: Style
    }

    private(set) var current: Toast?
    private var dismissTask: Task<Void, Never>?

    func show(_ message: String, _ style: Style = .info) {
        current = Toast(message: message, style: style)
        dismissTask?.cancel()
        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.2))
            if !Task.isCancelled { current = nil }
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        current = nil
    }
}

private struct ToastBanner: View {
    let toast: ToastCenter.Toast

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(toast.message)
                .font(.subheadline)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.surface3, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(Theme.borderDefault, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
    }

    private var icon: String {
        switch toast.style {
        case .success: "checkmark.circle.fill"
        case .error: "exclamationmark.triangle.fill"
        case .info: "info.circle.fill"
        }
    }

    private var tint: Color {
        switch toast.style {
        case .success: Theme.success
        case .error: Theme.error
        case .info: Theme.accent
        }
    }
}

private struct ToastHost: ViewModifier {
    @Environment(ToastCenter.self) private var center

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let toast = center.current {
                    ToastBanner(toast: toast)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                        .id(toast.id)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onTapGesture { center.dismiss() }
                }
            }
            .animation(.snappy, value: center.current)
    }
}

extension View {
    /// Hosts the bottom toast banner. Apply once near the app root.
    func toastHost() -> some View { modifier(ToastHost()) }
}
