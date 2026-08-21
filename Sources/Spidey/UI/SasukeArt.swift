import SwiftUI

// The Rinnegan, drawn in code for the theme entrance. It matches the emblem in
// the menu bar, which is the same eye drawn with AppKit.
enum SasukeArt {
    static let ink = Color(red: 0.086, green: 0.071, blue: 0.098)
    static let rinneganPurple = Color(red: 0.616, green: 0.596, blue: 0.784)
}

// A single tomoe: a round head trailing a tail that tapers to a point.
struct Tomoe: Shape {
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x * side, y: y * side)
        }
        var path = Path()
        path.addArc(
            center: point(0.34, 0.34),
            radius: 0.32 * side,
            startAngle: .degrees(-90),
            endAngle: .degrees(125),
            clockwise: false
        )
        path.addQuadCurve(to: point(0.97, 0.96), control: point(0.36, 1.04))
        path.addQuadCurve(to: point(0.34, 0.02), control: point(0.82, 0.28))
        path.closeSubpath()
        return path
    }
}

// His Rinnegan: concentric rings around a small pupil, with three tomoe riding
// the inner one.
struct RinneganDisc: View {
    let diameter: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [
                        Color(red: 0.788, green: 0.769, blue: 0.898),
                        SasukeArt.rinneganPurple,
                        Color(red: 0.243, green: 0.216, blue: 0.408),
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: diameter * 0.52
                ))
            ForEach([0.76, 0.52], id: \.self) { fraction in
                Circle()
                    .stroke(SasukeArt.ink.opacity(0.85), lineWidth: diameter * 0.055)
                    .frame(width: diameter * fraction, height: diameter * fraction)
            }
            ForEach(0..<3, id: \.self) { index in
                Tomoe()
                    .fill(SasukeArt.ink)
                    .frame(width: diameter * 0.17, height: diameter * 0.17)
                    .offset(y: -diameter * 0.19)
                    .rotationEffect(.degrees(Double(index) * 120))
            }
            Circle()
                .fill(SasukeArt.ink)
                .frame(width: diameter * 0.15, height: diameter * 0.15)
            Circle()
                .stroke(SasukeArt.ink, lineWidth: diameter * 0.07)
        }
        .frame(width: diameter, height: diameter)
    }
}

// The Rinnegan as it is painted in his eye: pale lavender, hairline rings, and
// six small tomoe in two rings of three. Lighter than the badge above, which
// has to hold up at menu bar size; this one sits on top of the artwork and has
// to disappear into it.
struct SasukeIris: View {
    let diameter: CGFloat

    private let lineColour = Color(red: 0.298, green: 0.267, blue: 0.404)

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [
                        Color(red: 0.812, green: 0.788, blue: 0.878),
                        Color(red: 0.729, green: 0.702, blue: 0.816),
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: diameter * 0.55
                ))
            ForEach([0.86, 0.64, 0.42], id: \.self) { fraction in
                Circle()
                    .stroke(lineColour.opacity(0.55), lineWidth: diameter * 0.008)
                    .frame(width: diameter * fraction, height: diameter * fraction)
            }
            ForEach(0..<6, id: \.self) { index in
                let inner = index % 2 == 0
                Tomoe()
                    .fill(SasukeArt.ink)
                    .frame(width: diameter * 0.105, height: diameter * 0.105)
                    .offset(y: -diameter * (inner ? 0.155 : 0.245))
                    .rotationEffect(.degrees(Double(index) * 60))
            }
            Circle()
                .fill(SasukeArt.ink)
                .frame(width: diameter * 0.072, height: diameter * 0.072)
            Circle()
                .stroke(lineColour.opacity(0.7), lineWidth: diameter * 0.01)
        }
        .frame(width: diameter, height: diameter)
    }
}
