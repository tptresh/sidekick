import AppKit
import SwiftUI

// Sasuke drawn for the theme entrance: a close up portrait in the style of the
// anime rather than the stubby figure in the menu bar. The two are separate
// drawings on purpose. The status item has to survive being 18 points wide, so
// it is a bold silhouette; this one is seen full screen, so it can carry a
// proper face, layered hair and the Sharingan spinning in his eye.
enum SasukeArt {
    static let hairDark = Color(red: 0.075, green: 0.086, blue: 0.137)
    static let hairLight = Color(red: 0.243, green: 0.267, blue: 0.376)
    static let skin = Color(red: 0.976, green: 0.894, blue: 0.831)
    static let skinShade = Color(red: 0.894, green: 0.776, blue: 0.706)
    static let ink = Color(red: 0.086, green: 0.071, blue: 0.098)
    static let shirt = Color(red: 0.788, green: 0.780, blue: 0.824)
    static let sharinganRed = Color(red: 0.741, green: 0.118, blue: 0.129)
    static let rinneganPurple = Color(red: 0.616, green: 0.596, blue: 0.784)

    // Landmarks in the 18 unit portrait box, y pointing down. The head fills
    // only part of that box, so callers centre on headCentre.
    static let sharinganEye = CGPoint(x: 7.75, y: 8.35)
    static let rinneganEye = CGPoint(x: 10.25, y: 8.35)
    static let headCentre = CGPoint(x: 9.3, y: 7.3)
    static let headWidthUnits: CGFloat = 10.2
    static let irisUnits: CGFloat = 1.15
}

// Everything below is drawn in the same 18 unit space, y pointing down.
private func unitPath(_ rect: CGRect, _ build: (inout Path, (CGFloat, CGFloat) -> CGPoint) -> Void) -> Path {
    let unit = rect.width / 18
    var path = Path()
    build(&path, { CGPoint(x: $0 * unit, y: $1 * unit) })
    return path
}

// The mass at the back of his head, spiking up and out behind everything else.
struct SasukeBackHair: Shape {
    func path(in rect: CGRect) -> Path {
        unitPath(rect) { path, point in
            path.move(to: point(5.6, 10.4))
            for spike in [
                (4.4, 8.4), (5.6, 7.4), (3.9, 5.8), (5.7, 5.2),
                (4.7, 2.9), (6.5, 4.0), (6.9, 1.5), (8.3, 3.2),
                (9.5, 1.1), (10.6, 3.2), (12.3, 1.4), (12.7, 3.8),
                (14.5, 2.7), (13.4, 5.2), (14.9, 6.0), (13.2, 7.2),
                (14.1, 8.8), (12.6, 9.6), (12.4, 10.4),
            ] {
                path.addLine(to: point(spike.0, spike.1))
            }
            path.addCurve(
                to: point(5.6, 10.4),
                control1: point(11.4, 11.6),
                control2: point(6.6, 11.6)
            )
            path.closeSubpath()
        }
    }
}

// His face: temples at the widest, cheeks running down to a soft pointed chin.
struct SasukeFace: Shape {
    func path(in rect: CGRect) -> Path {
        unitPath(rect) { path, point in
            path.move(to: point(6.35, 6.5))
            path.addCurve(to: point(9.0, 11.9), control1: point(6.4, 9.4), control2: point(8.0, 11.9))
            path.addCurve(to: point(11.65, 6.5), control1: point(10.0, 11.9), control2: point(11.6, 9.4))
            path.addCurve(to: point(6.35, 6.5), control1: point(11.7, 3.9), control2: point(6.3, 3.9))
            path.closeSubpath()
        }
    }
}

// The hair over his crown, hanging onto his forehead as separate pointed
// strands with forehead showing between them.
struct SasukeFrontHair: Shape {
    func path(in rect: CGRect) -> Path {
        unitPath(rect) { path, point in
            path.move(to: point(5.4, 6.5))
            path.addCurve(to: point(9.0, 3.0), control1: point(5.2, 4.0), control2: point(7.0, 3.0))
            path.addCurve(to: point(12.6, 6.5), control1: point(11.0, 3.0), control2: point(12.8, 4.0))
            path.addCurve(to: point(5.4, 6.5), control1: point(11.4, 6.9), control2: point(6.6, 6.9))
            path.closeSubpath()
        }
    }
}

// The strands of fringe hanging onto his forehead, all sweeping to his left.
struct SasukeFringe: Shape {
    func path(in rect: CGRect) -> Path {
        unitPath(rect) { path, point in
            for strand in [
                (base: (CGFloat(6.1), CGFloat(5.2)), width: CGFloat(1.6), tip: (CGFloat(7.9), CGFloat(7.4))),
                (base: (CGFloat(8.0), CGFloat(5.0)), width: CGFloat(1.5), tip: (CGFloat(9.7), CGFloat(7.6))),
                (base: (CGFloat(9.9), CGFloat(5.2)), width: CGFloat(1.5), tip: (CGFloat(11.4), CGFloat(7.2))),
            ] {
                let left = strand.base.0
                let right = left + strand.width
                path.move(to: point(left, strand.base.1))
                path.addLine(to: point(right, strand.base.1))
                path.addCurve(
                    to: point(strand.tip.0, strand.tip.1),
                    control1: point(right + 0.35, strand.base.1 + 0.9),
                    control2: point(strand.tip.0 + 0.2, strand.tip.1 - 0.8)
                )
                path.addCurve(
                    to: point(left, strand.base.1),
                    control1: point(right - 0.5, strand.base.1 + 1.5),
                    control2: point(left + 0.4, strand.base.1 + 0.7)
                )
                path.closeSubpath()
            }
        }
    }
}

// A long bang, wide at the temple and tapering to a point below his jaw.
struct SasukeBang: Shape {
    let mirrored: Bool

    func path(in rect: CGRect) -> Path {
        unitPath(rect) { path, raw in
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                raw(mirrored ? 18 - x : x, y)
            }
            path.move(to: point(4.7, 5.4))
            path.addCurve(to: point(5.9, 12.9), control1: point(4.8, 8.4), control2: point(5.3, 11.2))
            path.addCurve(to: point(6.5, 6.3), control1: point(6.2, 10.2), control2: point(6.6, 8.0))
            path.closeSubpath()
        }
    }
}

// One eye opening: a long lens, the upper lid heavier than the lower.
struct SasukeEye: Shape {
    let mirrored: Bool

    func path(in rect: CGRect) -> Path {
        unitPath(rect) { path, raw in
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                raw(mirrored ? 18 - x : x, y)
            }
            path.move(to: point(6.9, 8.5))
            path.addCurve(to: point(8.6, 8.2), control1: point(7.4, 7.75), control2: point(8.1, 7.8))
            path.addCurve(to: point(6.9, 8.5), control1: point(8.25, 8.85), control2: point(7.5, 9.0))
            path.closeSubpath()
        }
    }
}

// The high collar of his wrap top, open at the throat.
struct SasukeCollar: Shape {
    func path(in rect: CGRect) -> Path {
        unitPath(rect) { path, point in
            path.move(to: point(3.2, 18.0))
            path.addCurve(to: point(7.6, 12.9), control1: point(3.9, 15.2), control2: point(5.9, 13.2))
            path.addLine(to: point(9.0, 15.0))
            path.addLine(to: point(10.4, 12.9))
            path.addCurve(to: point(14.8, 18.0), control1: point(12.1, 13.2), control2: point(14.1, 15.2))
            path.closeSubpath()
        }
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

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [
                        Color(red: 0.937, green: 0.302, blue: 0.267),
                        SasukeArt.sharinganRed,
                        Color(red: 0.361, green: 0.043, blue: 0.063),
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: diameter * 0.52
                ))
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    Tomoe()
                        .fill(SasukeArt.ink)
                        .frame(width: diameter * 0.26, height: diameter * 0.26)
                        .offset(y: -diameter * 0.30)
                        .rotationEffect(.degrees(Double(index) * 120))
                }
                Circle()
                    .fill(SasukeArt.ink)
                    .frame(width: diameter * 0.17, height: diameter * 0.17)
            }
            .rotationEffect(.degrees(spin))
            Circle()
                .stroke(SasukeArt.ink, lineWidth: diameter * 0.05)
        }
        .frame(width: diameter, height: diameter)
    }
}

// The Rinnegan in his other eye: concentric rings around a small dark centre.
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
            Circle()
                .fill(SasukeArt.ink)
                .frame(width: diameter * 0.18, height: diameter * 0.18)
            Circle()
                .stroke(SasukeArt.ink, lineWidth: diameter * 0.07)
        }
        .frame(width: diameter, height: diameter)
    }
}

// The portrait: hair, face, and the two mismatched eyes from the figure, the
// left one already burning red.
struct SasukeHeadView: View {
    let side: CGFloat
    var glow: Bool = false

    private var unit: CGFloat { side / 18 }

    private var backHairFill: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.129, green: 0.145, blue: 0.216),
                Color(red: 0.055, green: 0.063, blue: 0.106),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var frontHairFill: LinearGradient {
        LinearGradient(
            colors: [SasukeArt.hairLight, SasukeArt.hairDark],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // The sheen the anime paints across the top of his hair.
    private var hairSheen: some View {
        Path { path in
            path.move(to: CGPoint(x: 6.7 * unit, y: 5.0 * unit))
            path.addQuadCurve(
                to: CGPoint(x: 11.3 * unit, y: 5.0 * unit),
                control: CGPoint(x: 9.0 * unit, y: 2.9 * unit)
            )
        }
        .stroke(
            Color(red: 0.435, green: 0.475, blue: 0.616).opacity(0.32),
            style: StrokeStyle(lineWidth: 0.3 * unit, lineCap: .round)
        )
        .mask(SasukeFrontHair().fill(Color.white))
    }

    var body: some View {
        ZStack {
            SasukeBackHair().fill(backHairFill)
            neck
            SasukeFace().fill(SasukeArt.skin)
            cheekShadow
            collar
            eye(mirrored: false, centre: SasukeArt.sharinganEye, lit: glow, tint: SasukeArt.sharinganRed) {
                SharinganDisc(diameter: SasukeArt.irisUnits * unit)
            }
            eye(mirrored: true, centre: SasukeArt.rinneganEye, lit: glow, tint: SasukeArt.rinneganPurple) {
                RinneganDisc(diameter: SasukeArt.irisUnits * unit)
            }
            brows
            nose
            mouth
            SasukeFrontHair().fill(frontHairFill)
            SasukeFringe().fill(frontHairFill)
            hairSheen
            SasukeBang(mirrored: false).fill(frontHairFill)
            SasukeBang(mirrored: true).fill(frontHairFill)
        }
        .frame(width: side, height: side)
    }

    // A soft shade under each cheekbone, the way the anime shades his face.
    private var cheekShadow: some View {
        ForEach([false, true], id: \.self) { mirrored in
            Path { path in
                func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                    CGPoint(x: (mirrored ? 18 - x : x) * unit, y: y * unit)
                }
                path.move(to: point(6.75, 8.9))
                path.addQuadCurve(to: point(8.0, 11.3), control: point(7.2, 10.4))
            }
            .stroke(
                SasukeArt.skinShade.opacity(0.55),
                style: StrokeStyle(lineWidth: 0.45 * unit, lineCap: .round)
            )
            .mask(SasukeFace().fill(Color.white))
        }
    }

    private var neck: some View {
        ZStack {
            Path { path in
                path.addRect(CGRect(x: 8.25 * unit, y: 10.9 * unit, width: 1.5 * unit, height: 2.4 * unit))
            }
            .fill(SasukeArt.skinShade)
            // The shadow his jaw throws, so the neck is not a bare post.
            Ellipse()
                .fill(Color(red: 0.784, green: 0.655, blue: 0.584))
                .frame(width: 1.6 * unit, height: 0.7 * unit)
                .position(x: 9.0 * unit, y: 11.35 * unit)
        }
    }

    private var collar: some View {
        ZStack {
            SasukeCollar().fill(SasukeArt.shirt)
            SasukeCollar().stroke(SasukeArt.ink.opacity(0.55), lineWidth: 0.09 * unit)
        }
    }

    // Eye white, iris clipped to the opening, then the heavy upper lid.
    private func eye<Disc: View>(
        mirrored: Bool,
        centre: CGPoint,
        lit: Bool,
        tint: Color,
        @ViewBuilder disc: () -> Disc
    ) -> some View {
        let shape = SasukeEye(mirrored: mirrored)
        return ZStack {
            shape.fill(Color(red: 0.965, green: 0.949, blue: 0.949))
            disc().position(x: centre.x * unit, y: centre.y * unit)
            shape.stroke(SasukeArt.ink, lineWidth: 0.1 * unit)
            upperLid(mirrored: mirrored)
        }
        .compositingGroup()
        .shadow(color: tint.opacity(lit ? 0.95 : 0), radius: lit ? 1.4 * unit : 0)
        .mask(shape.fill(Color.white).overlay(upperLid(mirrored: mirrored)))
    }

    private func upperLid(mirrored: Bool) -> some View {
        let unitSize = unit
        return Path { path in
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: (mirrored ? 18 - x : x) * unitSize, y: y * unitSize)
            }
            path.move(to: point(6.7, 8.4))
            path.addCurve(to: point(8.6, 8.15), control1: point(7.4, 7.65), control2: point(8.1, 7.7))
        }
        .stroke(SasukeArt.ink, style: StrokeStyle(lineWidth: 0.22 * unit, lineCap: .round))
    }

    private var brows: some View {
        ForEach([false, true], id: \.self) { mirrored in
            Path { path in
                func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                    CGPoint(x: (mirrored ? 18 - x : x) * unit, y: y * unit)
                }
                path.move(to: point(6.95, 7.15))
                path.addQuadCurve(to: point(8.5, 7.5), control: point(7.75, 7.08))
            }
            .stroke(SasukeArt.hairDark, style: StrokeStyle(lineWidth: 0.2 * unit, lineCap: .round))
        }
    }

    // Just the shadow down one side of it, the way the anime draws his nose.
    private var nose: some View {
        Path { path in
            path.move(to: CGPoint(x: 8.85 * unit, y: 9.4 * unit))
            path.addQuadCurve(
                to: CGPoint(x: 9.25 * unit, y: 10.3 * unit),
                control: CGPoint(x: 8.7 * unit, y: 10.1 * unit)
            )
        }
        .stroke(SasukeArt.skinShade, style: StrokeStyle(lineWidth: 0.12 * unit, lineCap: .round))
    }

    private var mouth: some View {
        Path { path in
            path.move(to: CGPoint(x: 8.35 * unit, y: 11.0 * unit))
            path.addQuadCurve(
                to: CGPoint(x: 9.65 * unit, y: 11.0 * unit),
                control: CGPoint(x: 9.0 * unit, y: 11.13 * unit)
            )
        }
        .stroke(SasukeArt.ink.opacity(0.8), style: StrokeStyle(lineWidth: 0.11 * unit, lineCap: .round))
    }
}
