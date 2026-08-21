import AppKit
import SwiftUI

// Sasuke's head and his Sharingan, for the theme entrance. The head reuses the
// menu bar emblem's geometry rather than restating it, so the figure in the
// status bar and the face on screen are the same drawing.
enum SasukeArt {
    static let hair = Color(red: 0.106, green: 0.114, blue: 0.161)
    static let skin = Color(red: 0.949, green: 0.827, blue: 0.725)
    static let sharinganRed = Color(red: 0.784, green: 0.149, blue: 0.157)
    static let rinneganPurple = Color(red: 0.478, green: 0.451, blue: 0.671)

    // Landmarks inside the 18 unit emblem box, y already flipped for SwiftUI.
    // The head fills only the top half of that box, since the rest of it holds
    // the body, so callers centre on headCentre rather than on the box.
    static let sharinganEye = CGPoint(x: 7.9, y: 5.0)
    static let rinneganEye = CGPoint(x: 10.1, y: 5.0)
    static let headCentre = CGPoint(x: 9.15, y: 4.15)
    static let headWidthUnits: CGFloat = 12.3
    static let irisUnits: CGFloat = 1.5
}

// NSBezierPath.cgPath needs macOS 14, so walk the elements by hand. The 18x18
// emblem space has y pointing up; SwiftUI's points down, hence the flip.
private func flipped(_ bezier: NSBezierPath, unit: CGFloat) -> Path {
    var path = Path()
    var points = [NSPoint](repeating: .zero, count: 3)
    for index in 0..<bezier.elementCount {
        let kind = bezier.element(at: index, associatedPoints: &points)
        func at(_ slot: Int) -> CGPoint {
            CGPoint(x: points[slot].x * unit, y: (18 - points[slot].y) * unit)
        }
        switch kind {
        case .moveTo: path.move(to: at(0))
        case .lineTo: path.addLine(to: at(0))
        case .curveTo: path.addCurve(to: at(2), control1: at(0), control2: at(1))
        case .closePath: path.closeSubpath()
        default: break
        }
    }
    return path
}

// The spiky silhouette with the face opening cut out of it.
struct SasukeHairShape: Shape {
    func path(in rect: CGRect) -> Path {
        let unit = rect.width / 18
        var path = flipped(StatusIcons.sasukeHairPath(), unit: unit)
        path.addPath(flipped(StatusIcons.sasukeFacePath(), unit: unit))
        return path
    }
}

// The face opening on its own, filled with skin behind the hair.
struct SasukeFaceShape: Shape {
    func path(in rect: CGRect) -> Path {
        flipped(StatusIcons.sasukeFacePath(), unit: rect.width / 18)
    }
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

// The Sharingan wheel: a red iris, a black pupil, and three orbiting tomoe.
struct SharinganDisc: View {
    let diameter: CGFloat
    var spin: Double = 0

    private let inkColor = Color(red: 0.09, green: 0.05, blue: 0.06)

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [
                        Color(red: 0.98, green: 0.35, blue: 0.30),
                        SasukeArt.sharinganRed,
                        Color(red: 0.42, green: 0.05, blue: 0.07),
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: diameter * 0.52
                ))
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    Tomoe()
                        .fill(inkColor)
                        .frame(width: diameter * 0.26, height: diameter * 0.26)
                        .offset(y: -diameter * 0.30)
                        .rotationEffect(.degrees(Double(index) * 120))
                }
                Circle()
                    .fill(inkColor)
                    .frame(width: diameter * 0.17, height: diameter * 0.17)
            }
            .rotationEffect(.degrees(spin))
            Circle()
                .stroke(inkColor, lineWidth: diameter * 0.05)
        }
        .frame(width: diameter, height: diameter)
    }
}

// The Rinnegan in his other eye: concentric rings around a small dark centre.
struct RinneganDisc: View {
    let diameter: CGFloat

    private let inkColor = Color(red: 0.09, green: 0.05, blue: 0.06)

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [
                        Color(red: 0.694, green: 0.667, blue: 0.831),
                        SasukeArt.rinneganPurple,
                        Color(red: 0.286, green: 0.259, blue: 0.435),
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: diameter * 0.52
                ))
            ForEach([0.72, 0.48], id: \.self) { fraction in
                Circle()
                    .stroke(inkColor.opacity(0.75), lineWidth: diameter * 0.045)
                    .frame(width: diameter * fraction, height: diameter * fraction)
            }
            Circle()
                .fill(inkColor)
                .frame(width: diameter * 0.17, height: diameter * 0.17)
            Circle()
                .stroke(inkColor, lineWidth: diameter * 0.05)
        }
        .frame(width: diameter, height: diameter)
    }
}

// The head as it appears during the entrance: skin, hair, brows, and the two
// mismatched eyes from the figure, the left one already burning red.
struct SasukeHeadView: View {
    let side: CGFloat
    var glow: Bool = false

    private var unit: CGFloat { side / 18 }

    var body: some View {
        ZStack {
            SasukeFaceShape().fill(SasukeArt.skin)
            // Both eyes as the figure paints them: a Sharingan on one side, a
            // Rinnegan on the other, sitting straight on the skin.
            eye(at: SasukeArt.sharinganEye, lit: glow, tint: SasukeArt.sharinganRed) {
                SharinganDisc(diameter: SasukeArt.irisUnits * unit)
            }
            eye(at: SasukeArt.rinneganEye, lit: false, tint: SasukeArt.rinneganPurple) {
                RinneganDisc(diameter: SasukeArt.irisUnits * unit)
            }
            nose
            mouth
            // Under the hair, so the fringe overlaps the inner ends of the brows.
            brows
            // A lit top edge and a rim: flat black hair would vanish into the
            // dimmed desktop behind the entrance.
            SasukeHairShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.204, green: 0.216, blue: 0.290),
                            SasukeArt.hair,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: FillStyle(eoFill: true)
                )
            SasukeHairShape()
                .stroke(Color(red: 0.416, green: 0.376, blue: 0.529).opacity(0.55),
                        lineWidth: 0.16 * unit)
        }
        .frame(width: side, height: side)
    }

    private func eye<Disc: View>(
        at centre: CGPoint,
        lit: Bool,
        tint: Color,
        @ViewBuilder disc: () -> Disc
    ) -> some View {
        disc()
            .shadow(color: tint.opacity(lit ? 0.95 : 0), radius: lit ? 1.8 * unit : 0)
            .position(x: centre.x * unit, y: centre.y * unit)
    }

    // A soft shadow for the nose and a flat, unimpressed mouth.
    private var nose: some View {
        Capsule()
            .fill(Color(red: 0.78, green: 0.63, blue: 0.55))
            .frame(width: 0.30 * unit, height: 0.55 * unit)
            .position(x: 9.0 * unit, y: 5.9 * unit)
    }

    private var mouth: some View {
        Capsule()
            .fill(Color(red: 0.60, green: 0.40, blue: 0.38))
            .frame(width: 1.5 * unit, height: 0.22 * unit)
            .position(x: 9.0 * unit, y: 6.6 * unit)
    }

    private var brows: some View {
        ForEach([false, true], id: \.self) { mirrored in
            Capsule()
                .fill(SasukeArt.hair)
                .frame(width: 1.6 * unit, height: 0.24 * unit)
                .rotationEffect(.degrees(mirrored ? -8 : 8))
                .position(x: (mirrored ? 18 - 7.9 : 7.9) * unit, y: 4.05 * unit)
        }
    }
}
