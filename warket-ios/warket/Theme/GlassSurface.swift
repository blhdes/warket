import SwiftUI

/// Centralizes Liquid Glass gating in one place. On iOS 26+ the content sits on a
/// real `glassEffect` surface; on iOS 17–25 it falls back to a frosted material
/// with a hairline border so the surface still reads as a floating panel.
extension View {
    @ViewBuilder
    func glassSurface<S: Shape>(
        in shape: S,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        if #available(iOS 26.0, *) {
            modifier(GlassSurfaceModifier(shape: shape, tint: tint, interactive: interactive))
        } else {
            background {
                shape.fill(.thinMaterial)
                    .overlay(shape.fill(tint?.opacity(0.16) ?? .clear))
                    .overlay(shape.stroke(Theme.borderDefault, lineWidth: 1))
            }
        }
    }
}

@available(iOS 26.0, *)
private struct GlassSurfaceModifier<S: Shape>: ViewModifier {
    let shape: S
    let tint: Color?
    let interactive: Bool

    func body(content: Content) -> some View {
        var effect: Glass = .regular
        if let tint { effect = effect.tint(tint) }
        if interactive { effect = effect.interactive() }
        return content.glassEffect(effect, in: shape)
    }
}

/// Wraps children in a `GlassEffectContainer` on iOS 26 so adjacent glass shapes
/// refract into each other; a plain `VStack` elsewhere. Zero layout cost on the
/// fallback path.
struct GlassStack<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder var content: () -> Content

    init(spacing: CGFloat = 10, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { VStack(spacing: spacing) { content() } }
        } else {
            VStack(spacing: spacing) { content() }
        }
    }
}
