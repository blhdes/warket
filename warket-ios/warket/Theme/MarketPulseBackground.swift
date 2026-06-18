import SwiftUI

/// Ambient "market pulse" backdrop — the native echo of the web landing's animated
/// canvas. A slow teal-on-dark `MeshGradient` (iOS 18+) whose interior control
/// points drift on a long Lissajous cycle, capped with a dark scrim so foreground
/// text stays readable. On iOS 17 it degrades to a fixed teal→dark gradient, and
/// under Reduce Motion the mesh freezes on its phase-0 frame.
struct MarketPulseBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Theme.surface0
            mesh
            Color.black.opacity(0.25)
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var mesh: some View {
        if #available(iOS 18.0, *) {
            TimelineView(.animation(minimumInterval: reduceMotion ? .infinity : 1.0 / 30.0)) { timeline in
                let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                MeshGradient(
                    width: 3,
                    height: 3,
                    points: Self.meshPoints(at: t),
                    colors: Self.meshColors
                )
            }
        } else {
            LinearGradient(
                colors: [Theme.surface0, Color(hex: 0x123A37), Theme.surface1],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    /// Teal pools through the middle band; corners stay near-black. Phase 0 of the
    /// animation IS this resting composition, so the Reduce-Motion freeze frame
    /// renders exactly the design reviewed by eye.
    private static let meshColors: [Color] = [
        Theme.surface0,        Theme.surface1,        Theme.surface0,
        Color(hex: 0x123A37),  Color(hex: 0x1C5F57),  Color(hex: 0x10302E),
        Theme.surface0,        Color(hex: 0x14403B),  Theme.surface1,
    ]

    /// 3×3 control grid. Corners are pinned; the center and the four edge-midpoints
    /// wander gently — the midpoints only along their own edge so every point stays
    /// strictly inside `[0, 1]` (out-of-bounds points tear the mesh into empty
    /// triangles).
    @available(iOS 18.0, *)
    private static func meshPoints(at t: TimeInterval) -> [SIMD2<Float>] {
        func osc(_ phase: Double, _ speed: Double, _ amp: Double) -> Float {
            Float(amp * sin(t * speed + phase))
        }
        let topX   = 0.5 + osc(2.1, 0.31, 0.05)
        let botX   = 0.5 + osc(0.7, 0.29, 0.05)
        let leftY  = 0.5 + osc(1.9, 0.33, 0.05)
        let rightY = 0.5 + osc(3.4, 0.27, 0.05)
        let cx     = 0.5 + osc(0.0, 0.42, 0.06)
        let cy     = 0.5 + osc(1.3, 0.37, 0.06)
        return [
            SIMD2(0, 0),     SIMD2(topX, 0), SIMD2(1, 0),
            SIMD2(0, leftY), SIMD2(cx, cy),  SIMD2(1, rightY),
            SIMD2(0, 1),     SIMD2(botX, 1), SIMD2(1, 1),
        ]
    }
}
