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

// The six tomoe in his Rinnegan, spun on the spot.
//
// Their positions, size and the way each one points were measured off the
// artwork. Each is covered with the lavender that surrounds it and drawn again
// on top, so it can turn without the painted one showing through. The rest of
// his eye is left exactly as it was: rotating the iris itself means undoing the
// ellipse his eye is turned into, and no fit is close enough to stop the rings
// beating against the ones underneath.
struct SasukeTomoe: View {
    let display: CGSize
    let spin: Double

    // Position as a fraction of the picture, and how far the comma is turned
    // where it sits, so it lies along the ring the way the painted one does.
    private static let places: [(x: CGFloat, y: CGFloat, phase: Double)] = [
        (0.4924, 0.4349, 0.2),
        (0.5761, 0.4387, 53.4),
        (0.3996, 0.4595, -61.3),
        (0.5493, 0.5867, 110.2),
        (0.4427, 0.6040, 238.2),
        (0.4985, 0.7463, 176.7),
    ]

    // The iris immediately around every one of them, sampled from the picture.
    private static let iris = Color(red: 198 / 255, green: 183 / 255, blue: 206 / 255)

    var body: some View {
        let patch = display.width * 0.054
        let mark = display.width * 0.048
        ForEach(Array(Self.places.enumerated()), id: \.offset) { _, place in
            ZStack {
                Circle()
                    .fill(Self.iris)
                    .frame(width: patch, height: patch)
                Tomoe()
                    .fill(SasukeArt.ink)
                    .frame(width: mark, height: mark)
                    // The comma is not centred in its own box, so it is nudged
                    // over to turn about itself rather than swing.
                    .offset(x: 0.05 * mark, y: 0.05 * mark)
                    .rotationEffect(.degrees(place.phase + spin))
            }
            .position(x: place.x * display.width, y: place.y * display.height)
        }
    }
}
