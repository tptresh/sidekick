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
