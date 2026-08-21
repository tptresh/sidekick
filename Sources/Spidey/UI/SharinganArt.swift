import SwiftUI

// The Sharingan drawn in code for the theme entrance, in the same three parts
// the animation needs to move separately: the red iris, the ring of tomoe that
// spins around it, and the pupil that stays put.
enum SharinganArt {
    static let ink = Color(red: 0.051, green: 0.020, blue: 0.027)
    static let blood = Color(red: 0.784, green: 0.071, blue: 0.114)
    static let ember = Color(red: 0.980, green: 0.286, blue: 0.235)
}

// The iris: a hot centre falling off to a dark rim, with the fibres of the eye
// radiating out of the pupil and a heavy limbal ring holding it all in. Left
// slightly short of opaque so whatever it covers still ghosts through.
struct SharinganIris: View {
    let diameter: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [
                        SharinganArt.ember,
                        SharinganArt.blood,
                        Color(red: 0.522, green: 0.031, blue: 0.075),
                        Color(red: 0.294, green: 0.012, blue: 0.043),
                    ],
                    center: .center,
                    startRadius: diameter * 0.05,
                    endRadius: diameter * 0.52
                ))
                .opacity(0.88)
            fibres
            Circle()
                .stroke(SharinganArt.ink, lineWidth: diameter * 0.030)
                .frame(width: diameter * 0.970, height: diameter * 0.970)
        }
        .frame(width: diameter, height: diameter)
    }

    // Fine strands radiating from the pupil, alternating light and dark so the
    // iris has grain rather than reading as a flat disc.
    private var fibres: some View {
        ForEach(0..<60, id: \.self) { index in
            let wobble = Double((index * 37) % 13) / 13.0
            Capsule()
                .fill(
                    (index % 2 == 0 ? SharinganArt.ink : SharinganArt.ember)
                        .opacity(0.015 + wobble * 0.025)
                )
                .frame(
                    width: diameter * (0.002 + wobble * 0.003),
                    height: diameter * (0.16 + wobble * 0.14)
                )
                .offset(y: -diameter * (0.26 + wobble * 0.04))
                .rotationEffect(.degrees(Double(index) * 6))
        }
        .mask(Circle().frame(width: diameter * 0.94, height: diameter * 0.94))
    }
}

// One tomoe parked in its slot around the pupil, matching the emblem in the
// menu bar. The whole set spins by rotating the container they sit in.
struct SharinganTomoe: View {
    let diameter: CGFloat
    let index: Int

    // Finer and further out than the menu bar emblem, which has to stay bold
    // enough to read at 18 points. Across a whole moon that weight looks heavy.
    private var glyph: CGFloat { diameter * 0.180 }
    private var orbit: CGFloat { diameter * 0.325 }

    var body: some View {
        ZStack {
            Circle()
                .fill(SharinganArt.ink)
                .frame(width: glyph * 0.60, height: glyph * 0.60)
                .offset(x: -glyph * 0.18, y: glyph * 0.18)
            TomoeTail()
                .fill(SharinganArt.ink)
        }
        .frame(width: glyph, height: glyph)
        .offset(x: glyph * 0.18, y: -orbit - glyph * 0.18)
        .rotationEffect(.degrees(Double(index) * 120))
    }
}

// The tail: away from the bulb tangentially, over the top to a point, then
// hooking back in.
private struct TomoeTail: Shape {
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * side, y: rect.minY + y * side)
        }
        var path = Path()
        path.move(to: point(0.048, 0.553))
        path.addCurve(
            to: point(1.040, 0.080),
            control1: point(0.226, 0.173),
            control2: point(0.770, 0.170)
        )
        path.addCurve(
            to: point(0.619, 0.654),
            control1: point(0.811, 0.156),
            control2: point(0.652, 1.030)
        )
        path.closeSubpath()
        return path
    }
}

// The pupil, with the faint bright rim the eye has where it meets the iris.
struct SharinganPupil: View {
    let diameter: CGFloat

    var body: some View {
        Circle()
            .fill(SharinganArt.ink)
            .overlay(
                Circle().stroke(SharinganArt.ember.opacity(0.30), lineWidth: diameter * 0.012)
            )
            .frame(width: diameter * 0.15, height: diameter * 0.15)
    }
}
