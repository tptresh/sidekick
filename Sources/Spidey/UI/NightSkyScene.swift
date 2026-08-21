import SwiftUI

// The scene the Sharingan entrance plays over: a red night sky, a huge low
// moon, and a power pole with a figure crouched on top of it. Everything in
// front of the moon is flat black, so the whole picture is a silhouette.

// Repeatable scatter, so the stars and craters land in the same place on every
// replay instead of jittering.
func sceneNoise(_ index: Int, _ salt: Int) -> CGFloat {
    let value = sin(Double(index) * 12.9898 + Double(salt) * 78.233) * 43758.5453
    return CGFloat(value - value.rounded(.down))
}

struct NightSky: View {
    let size: CGSize

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.020, green: 0.004, blue: 0.012),
                    Color(red: 0.114, green: 0.012, blue: 0.043),
                    Color(red: 0.310, green: 0.020, blue: 0.063),
                    Color(red: 0.502, green: 0.024, blue: 0.075),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            stars
            clouds
        }
        .frame(width: size.width, height: size.height)
    }

    private var stars: some View {
        ForEach(0..<70, id: \.self) { index in
            let radius = 0.7 + sceneNoise(index, 5) * 1.6
            Circle()
                .fill(Color.white.opacity(0.25 + Double(sceneNoise(index, 9)) * 0.6))
                .frame(width: radius * 2, height: radius * 2)
                .position(
                    x: sceneNoise(index, 1) * size.width,
                    y: sceneNoise(index, 2) * size.height * 0.72
                )
        }
    }

    // Lit cloud banks along the horizon, the way the moon underlights them.
    private var clouds: some View {
        ForEach(0..<6, id: \.self) { index in
            let width = size.width * (0.22 + sceneNoise(index, 21) * 0.26)
            Ellipse()
                .fill(RadialGradient(
                    colors: [
                        Color(red: 0.925, green: 0.114, blue: 0.204).opacity(0.55),
                        Color(red: 0.612, green: 0.031, blue: 0.098).opacity(0.20),
                        .clear,
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: width * 0.5
                ))
                .frame(width: width, height: width * 0.34)
                .position(
                    x: sceneNoise(index, 3) * size.width,
                    y: size.height * (0.74 + sceneNoise(index, 4) * 0.24)
                )
        }
    }
}

struct MoonDisc: View {
    let diameter: CGFloat

    var body: some View {
        Circle()
            .fill(RadialGradient(
                colors: [
                    Color(red: 0.988, green: 0.965, blue: 0.988),
                    Color(red: 0.929, green: 0.847, blue: 0.918),
                    Color(red: 0.808, green: 0.667, blue: 0.788),
                ],
                center: UnitPoint(x: 0.42, y: 0.36),
                startRadius: 0,
                endRadius: diameter * 0.62
            ))
            .overlay(MoonCraters(diameter: diameter))
            .frame(width: diameter, height: diameter)
            .clipShape(Circle())
    }
}

// Drawn separately so the eye can wear the same pockmarks once it has taken
// the moon over.
struct MoonCraters: View {
    let diameter: CGFloat

    var body: some View {
        ForEach(0..<16, id: \.self) { index in
            let span = diameter * (0.03 + sceneNoise(index, 31) * 0.09)
            // Placed on a circle of random radius, which keeps them inside.
            let angle = Double(sceneNoise(index, 33)) * 2 * .pi
            let distance = diameter * 0.45 * sqrt(sceneNoise(index, 35))
            let shade = 0.10 + Double(sceneNoise(index, 37)) * 0.12
            Circle()
                .fill(RadialGradient(
                    colors: [
                        Color(red: 0.239, green: 0.161, blue: 0.263).opacity(shade),
                        Color(red: 0.239, green: 0.161, blue: 0.263).opacity(shade * 0.5),
                        .clear,
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: span * 0.5
                ))
                .frame(width: span, height: span)
                .offset(x: CGFloat(cos(angle)) * distance, y: CGFloat(sin(angle)) * distance)
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
    }
}

// The pole itself: mast, crossarm, insulators and the two transformer cans.
struct PoleBody: Shape {
    let topY: CGFloat

    func path(in rect: CGRect) -> Path {
        let centerX = rect.midX
        let unit = min(rect.width, rect.height)
        let armY = topY + unit * 0.10
        let armHalf = unit * 0.17
        var path = Path()

        // Mast, tapering very slightly on the way down.
        path.addRect(CGRect(
            x: centerX - unit * 0.014, y: topY,
            width: unit * 0.028, height: rect.height - topY
        ))
        // Crossarm with a brace under it.
        path.addRect(CGRect(
            x: centerX - armHalf, y: armY,
            width: armHalf * 2, height: unit * 0.013
        ))
        path.addRect(CGRect(
            x: centerX - armHalf * 0.45, y: armY + unit * 0.045,
            width: armHalf * 0.9, height: unit * 0.008
        ))
        // Insulator pegs standing on the arm.
        for step in stride(from: -1.0, through: 1.0, by: 0.5) {
            path.addRect(CGRect(
                x: centerX + armHalf * CGFloat(step) - unit * 0.006,
                y: armY - unit * 0.022,
                width: unit * 0.012, height: unit * 0.022
            ))
        }
        // Transformer cans slung below the arm.
        for side in [-1.0, 1.0] as [CGFloat] {
            path.addRoundedRect(
                in: CGRect(
                    x: centerX + side * unit * 0.075 - unit * 0.024,
                    y: armY + unit * 0.075,
                    width: unit * 0.048, height: unit * 0.095
                ),
                cornerSize: CGSize(width: unit * 0.008, height: unit * 0.008)
            )
        }
        return path
    }
}

// Lines fanning off the pole to both edges, sagging under their own weight.
struct PoleWires: Shape {
    let topY: CGFloat

    func path(in rect: CGRect) -> Path {
        let centerX = rect.midX
        let unit = min(rect.width, rect.height)
        let armY = topY + unit * 0.10
        var path = Path()

        for index in 0..<8 {
            let spread = CGFloat(index)
            let jitter = sceneNoise(index, 61)
            let anchor = CGPoint(
                x: centerX - unit * (0.015 + spread * 0.021 + jitter * 0.03),
                y: armY + unit * (0.004 + spread * 0.016)
            )
            // Mirrored horizontally but hung at its own height, so the two
            // sides never line up into a symmetrical web.
            let mirrored = CGPoint(
                x: 2 * centerX - anchor.x + unit * jitter * 0.02,
                y: armY + unit * (0.004 + spread * 0.019)
            )
            let dropLeft = rect.height * (0.02 + spread * 0.05 + Double(jitter) * 0.04)
            let dropRight = rect.height * (0.03 + spread * 0.045 + Double(sceneNoise(index, 67)) * 0.05)

            path.move(to: anchor)
            path.addQuadCurve(
                to: CGPoint(x: -unit * 0.02, y: anchor.y + dropLeft),
                control: CGPoint(x: centerX * (0.30 + jitter * 0.25), y: anchor.y + dropLeft * 1.6)
            )
            path.move(to: mirrored)
            path.addQuadCurve(
                to: CGPoint(x: rect.width + unit * 0.02, y: mirrored.y + dropRight),
                control: CGPoint(x: centerX * (1.55 + jitter * 0.3), y: mirrored.y + dropRight * 1.6)
            )
        }
        // Two lines running clear across in front of everything.
        for offset in [0.10, 0.19] as [CGFloat] {
            let edgeY = armY + rect.height * offset
            path.move(to: CGPoint(x: -unit * 0.02, y: edgeY))
            path.addQuadCurve(
                to: CGPoint(x: rect.width + unit * 0.02, y: edgeY + rect.height * 0.03),
                control: CGPoint(x: centerX, y: edgeY + rect.height * 0.13)
            )
        }
        return path
    }
}

// The figure crouched on top of the pole: knees drawn up, long hair down the
// back, and the headband tails streaming off to one side. Built from separate
// masses that overlap into one silhouette, which is easier to keep in
// proportion than a single outline.
struct PerchedFigure: View {
    let height: CGFloat

    private var width: CGFloat { height * 1.15 }

    var body: some View {
        ZStack {
            crouch
            hair
            head
            HeadbandTails().fill(Color.black)
        }
        .frame(width: width, height: height)
    }

    // Hunched shoulders flaring into knees, then shins down to planted feet.
    private var crouch: some View {
        Crouch().fill(Color.black)
    }

    private var hair: some View {
        Ellipse()
            .fill(Color.black)
            .frame(width: width * 0.36, height: height * 0.42)
            .offset(x: width * 0.02, y: -height * 0.20)
    }

    private var head: some View {
        Circle()
            .fill(Color.black)
            .frame(width: height * 0.23, height: height * 0.23)
            .offset(y: -height * 0.355)
    }

}

// Two coals where the Sharingan opens on him too. Drawn over the figure rather
// than inside it, so they can light up on their own.
struct PerchedFigureEyes: View {
    let height: CGFloat

    var body: some View {
        ForEach([-1.0, 1.0], id: \.self) { side in
            Capsule()
                .fill(SharinganArt.ember)
                .frame(width: height * 0.052, height: height * 0.024)
                .shadow(color: SharinganArt.blood, radius: height * 0.06)
                .offset(x: CGFloat(side) * height * 0.048, y: -height * 0.345)
        }
        .frame(width: height * 1.15, height: height)
    }
}

private struct Crouch: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var path = Path()
        // Right shoulder out to the knee, then the shin down to the foot.
        path.move(to: point(0.50, 0.30))
        path.addQuadCurve(to: point(0.70, 0.44), control: point(0.66, 0.31))
        path.addQuadCurve(to: point(0.83, 0.68), control: point(0.86, 0.55))
        path.addQuadCurve(to: point(0.79, 0.93), control: point(0.82, 0.84))
        path.addLine(to: point(0.86, 1.00))
        path.addLine(to: point(0.57, 1.00))
        // Notch between the legs.
        path.addQuadCurve(to: point(0.50, 0.80), control: point(0.54, 0.90))
        path.addQuadCurve(to: point(0.43, 1.00), control: point(0.46, 0.90))
        path.addLine(to: point(0.14, 1.00))
        path.addLine(to: point(0.21, 0.93))
        path.addQuadCurve(to: point(0.17, 0.68), control: point(0.18, 0.84))
        path.addQuadCurve(to: point(0.30, 0.44), control: point(0.14, 0.55))
        path.addQuadCurve(to: point(0.50, 0.30), control: point(0.34, 0.31))
        path.closeSubpath()
        return path
    }
}

private struct HeadbandTails: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var path = Path()
        for (tip, lift, root) in [
            (CGFloat(-0.30), CGFloat(0.02), CGFloat(0.22)),
            (CGFloat(-0.12), CGFloat(0.19), CGFloat(0.28)),
        ] {
            path.move(to: point(0.40, root))
            path.addQuadCurve(to: point(tip, lift), control: point(0.05, lift + 0.10))
            path.addQuadCurve(to: point(0.40, root + 0.07), control: point(0.08, lift + 0.16))
            path.closeSubpath()
        }
        return path
    }
}
