import SwiftUI

/// Orev, the owl revenue consultant. Drawn in vector so it stays crisp at any size.
/// Animation pauses entirely with Reduce Motion; each state keeps a distinct still pose.
struct OrevView: View {
    let state: OrevState
    var size: CGFloat = 96
    /// Pass false for historical/secondary appearances to save battery.
    var isAnimated: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var animates: Bool { isAnimated && !reduceMotion && !LaunchFlags.stillOrev }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !animates)) { timeline in
            let t = animates ? timeline.date.timeIntervalSinceReferenceDate : 0
            let pose = OrevPose.make(state, t: t, animated: animates)
            Canvas { ctx, canvasSize in
                let s = min(canvasSize.width, canvasSize.height) / 100
                ctx.translateBy(x: (canvasSize.width - 100 * s) / 2, y: (canvasSize.height - 100 * s) / 2)
                ctx.scaleBy(x: s, y: s)
                OrevPainter.draw(ctx, pose)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Orev")
        .accessibilityValue(state.accessibilityDescription)
    }
}

enum OrevColors {
    static let bodyTop = Color(light: 0x24396A, dark: 0x30508A)
    static let bodyTopLight = Color(light: 0x31497C, dark: 0x3D5E9A)
    static let bodyBottom = Color(light: 0x14223F, dark: 0x1D3058)
    static let wing = Color(light: 0x1C2E55, dark: 0x284276)
    static let rim = Color(light: 0x0B1427, dark: 0x8FA4D0)
    static let face = Color(hex: 0xF7F2E9)
    static let belly = Color(hex: 0xE4DCCB)
    static let pupil = Color(hex: 0x0B1427)
    static let amberLight = Color(hex: 0xFFD27A)
    static let amber = Color(hex: 0xF2A332)
    static let amberDeep = Color(hex: 0xB8651A)
    static let beak = Color(hex: 0x3B4C70)
    static let beakLight = Color(hex: 0x8898BC)
    static let glow = Color(hex: 0xF5B94F)
}

enum OrevPainter {
    static func draw(_ ctx: GraphicsContext, _ p: OrevPose) {
        if p.glow > 0 {
            ctx.fill(
                Path(ellipseIn: CGRect(x: 2, y: 6, width: 96, height: 96)),
                with: .radialGradient(
                    Gradient(colors: [OrevColors.glow.opacity(0.5 * p.glow), OrevColors.glow.opacity(0)]),
                    center: CGPoint(x: 50, y: 56), startRadius: 8, endRadius: 50
                )
            )
        }
        if let phase = p.confettiPhase { drawConfetti(ctx, phase) }
        ctx.fill(Path(ellipseIn: CGRect(x: 30, y: 91, width: 40, height: 5)), with: .color(.black.opacity(0.12)))

        var body = ctx
        body.translateBy(x: 0, y: p.bob)
        drawWing(body, shoulder: CGPoint(x: 31, y: 55), angle: p.leftWing)
        drawWing(body, shoulder: CGPoint(x: 69, y: 55), angle: -p.rightWing)

        let torso = Path(ellipseIn: CGRect(x: 23, y: 36, width: 54, height: 56))
        body.fill(torso, with: .linearGradient(
            Gradient(colors: [OrevColors.bodyTop, OrevColors.bodyBottom]),
            startPoint: CGPoint(x: 50, y: 36), endPoint: CGPoint(x: 50, y: 92)
        ))
        body.stroke(torso, with: .color(OrevColors.rim.opacity(0.35)), lineWidth: 0.8)

        body.fill(Path(ellipseIn: CGRect(x: 34, y: 58, width: 32, height: 29)), with: .color(OrevColors.belly))
        var chevrons = Path()
        let rows: [(Double, [Double])] = [(65, [45, 55]), (71, [41, 50, 59]), (77, [45, 55])]
        for (y, xs) in rows {
            for x in xs {
                chevrons.move(to: CGPoint(x: x - 2.4, y: y))
                chevrons.addLine(to: CGPoint(x: x, y: y + 2.2))
                chevrons.addLine(to: CGPoint(x: x + 2.4, y: y))
            }
        }
        body.stroke(chevrons, with: .color(OrevColors.bodyBottom.opacity(0.35)), style: StrokeStyle(lineWidth: 1.1, lineCap: .round, lineJoin: .round))

        for x in [39.0, 54.0] {
            body.fill(Path(roundedRect: CGRect(x: x, y: 88, width: 7, height: 4.5), cornerRadius: 2.2), with: .color(OrevColors.amber))
        }

        var head = body
        head.translateBy(x: 50, y: 46)
        head.rotate(by: .degrees(p.tilt))
        head.translateBy(x: -50, y: -46)
        drawHead(head, p)

        if let phase = p.listenPhase { drawListening(ctx, phase) }
        if let phase = p.dotsPhase { drawDots(ctx, phase) }
        if let phase = p.questionPhase { drawQuestion(ctx, phase) }
        if let phase = p.sparklePhase { drawSparkles(ctx, phase) }
        if let phase = p.sweatPhase { drawSweat(ctx, phase) }
    }

    private static func circle(_ r: CGFloat, at c: CGPoint = .zero) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }

    private static func drawWing(_ ctx: GraphicsContext, shoulder: CGPoint, angle: Double) {
        var w = ctx
        w.translateBy(x: shoulder.x, y: shoulder.y)
        w.rotate(by: .degrees(angle))
        let wing = Path(ellipseIn: CGRect(x: -7, y: -3, width: 13, height: 31))
        w.fill(wing, with: .linearGradient(
            Gradient(colors: [OrevColors.wing, OrevColors.bodyBottom]),
            startPoint: CGPoint(x: 0, y: -3), endPoint: CGPoint(x: 0, y: 28)
        ))
        w.stroke(wing, with: .color(OrevColors.rim.opacity(0.3)), lineWidth: 0.6)
    }

    private static func drawHead(_ h: GraphicsContext, _ p: OrevPose) {
        var tufts = Path()
        tufts.move(to: CGPoint(x: 25, y: 31))
        tufts.addLine(to: CGPoint(x: 29, y: 10 - p.earLift))
        tufts.addLine(to: CGPoint(x: 42, y: 23))
        tufts.closeSubpath()
        tufts.move(to: CGPoint(x: 75, y: 31))
        tufts.addLine(to: CGPoint(x: 71, y: 10 - p.earLift))
        tufts.addLine(to: CGPoint(x: 58, y: 23))
        tufts.closeSubpath()
        h.fill(tufts, with: .color(OrevColors.bodyTop))

        let skull = Path(ellipseIn: CGRect(x: 21, y: 17, width: 58, height: 48))
        h.fill(skull, with: .linearGradient(
            Gradient(colors: [OrevColors.bodyTopLight, OrevColors.bodyTop]),
            startPoint: CGPoint(x: 50, y: 17), endPoint: CGPoint(x: 50, y: 65)
        ))
        h.stroke(skull, with: .color(OrevColors.rim.opacity(0.35)), lineWidth: 0.8)

        var disk = Path(ellipseIn: CGRect(x: 24.5, y: 27.5, width: 30, height: 30))
        disk.addEllipse(in: CGRect(x: 45.5, y: 27.5, width: 30, height: 30))
        h.fill(disk, with: .color(OrevColors.face))

        var crest = Path()
        crest.move(to: CGPoint(x: 40, y: 26))
        crest.addLine(to: CGPoint(x: 50, y: 39))
        crest.addLine(to: CGPoint(x: 60, y: 26))
        crest.addLine(to: CGPoint(x: 50, y: 31))
        crest.closeSubpath()
        h.fill(crest, with: .color(OrevColors.bodyTop))

        drawEye(h, center: CGPoint(x: 39.5, y: 43), p)
        drawEye(h, center: CGPoint(x: 60.5, y: 43), p)

        var brows = Path()
        switch p.brows {
        case .flat:
            break
        case .curious:
            brows.move(to: CGPoint(x: 32, y: 30))
            brows.addLine(to: CGPoint(x: 45, y: 31.5))
            brows.move(to: CGPoint(x: 55, y: 29 - p.browRaise))
            brows.addLine(to: CGPoint(x: 68, y: 26 - p.browRaise * 1.4))
        case .worried:
            brows.move(to: CGPoint(x: 31, y: 31))
            brows.addLine(to: CGPoint(x: 45, y: 27.5))
            brows.move(to: CGPoint(x: 55, y: 27.5))
            brows.addLine(to: CGPoint(x: 69, y: 31))
        }
        if p.brows != .flat {
            h.stroke(brows, with: .color(OrevColors.pupil), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }

        let o = p.beakOpen
        var upper = Path()
        upper.move(to: CGPoint(x: 45.5, y: 50))
        upper.addLine(to: CGPoint(x: 54.5, y: 50))
        upper.addLine(to: CGPoint(x: 50, y: 57 - o * 1.5))
        upper.closeSubpath()
        h.fill(upper, with: .linearGradient(
            Gradient(colors: [OrevColors.beakLight, OrevColors.beak]),
            startPoint: CGPoint(x: 50, y: 50), endPoint: CGPoint(x: 50, y: 57)
        ))
        if o > 0.05 {
            var lower = Path()
            lower.move(to: CGPoint(x: 47.5, y: 56 + o))
            lower.addLine(to: CGPoint(x: 52.5, y: 56 + o))
            lower.addLine(to: CGPoint(x: 50, y: 59 + o * 2.2))
            lower.closeSubpath()
            h.fill(lower, with: .color(OrevColors.beak))
        }
    }

    private static func drawEye(_ h: GraphicsContext, center: CGPoint, _ p: OrevPose) {
        var e = h
        e.translateBy(x: center.x, y: center.y)
        if p.happyEyes {
            var arc = Path()
            arc.move(to: CGPoint(x: -7, y: 2))
            arc.addQuadCurve(to: CGPoint(x: 7, y: 2), control: CGPoint(x: 0, y: -8))
            e.stroke(arc, with: .color(OrevColors.pupil), style: StrokeStyle(lineWidth: 2.8, lineCap: .round))
            return
        }
        e.scaleBy(x: p.eyeScale, y: p.eyeScale * max(0.08, p.eyeOpen))
        e.fill(circle(10.5), with: .color(OrevColors.pupil))
        e.fill(circle(8.2), with: .radialGradient(
            Gradient(colors: [OrevColors.amberLight, OrevColors.amber, OrevColors.amberDeep]),
            center: CGPoint(x: -1.5, y: -1.5), startRadius: 0.5, endRadius: 9
        ))
        let pc = CGPoint(x: p.pupil.width, y: p.pupil.height)
        e.fill(circle(4.4, at: pc), with: .color(OrevColors.pupil))
        e.fill(circle(1.7, at: CGPoint(x: pc.x - 2.2, y: pc.y - 2.4)), with: .color(.white))
    }

    private static func drawDots(_ ctx: GraphicsContext, _ phase: Double) {
        for i in 0..<3 {
            let pulse = 0.35 + 0.65 * (0.5 + 0.5 * sin(phase * 4 - Double(i) * 0.9))
            let c = CGPoint(x: 78 + Double(i) * 7, y: 20 - Double(i) * 6)
            ctx.fill(circle(1.9 + Double(i) * 0.7, at: c), with: .color(Palette.teal.opacity(pulse)))
        }
    }

    private static func drawQuestion(_ ctx: GraphicsContext, _ phase: Double) {
        let dy = sin(phase * 2) * 1.5
        ctx.draw(
            Text("?").font(.system(size: 18, weight: .heavy, design: .rounded)).foregroundStyle(Palette.gold),
            at: CGPoint(x: 84, y: 16 + dy)
        )
    }

    private static func star(_ c: CGPoint, _ r: CGFloat) -> Path {
        var s = Path()
        let k = r * 0.3
        s.move(to: CGPoint(x: c.x, y: c.y - r))
        s.addLine(to: CGPoint(x: c.x + k, y: c.y - k))
        s.addLine(to: CGPoint(x: c.x + r, y: c.y))
        s.addLine(to: CGPoint(x: c.x + k, y: c.y + k))
        s.addLine(to: CGPoint(x: c.x, y: c.y + r))
        s.addLine(to: CGPoint(x: c.x - k, y: c.y + k))
        s.addLine(to: CGPoint(x: c.x - r, y: c.y))
        s.addLine(to: CGPoint(x: c.x - k, y: c.y - k))
        s.closeSubpath()
        return s
    }

    private static func drawSparkles(_ ctx: GraphicsContext, _ phase: Double) {
        let spots: [(CGFloat, CGFloat, Double)] = [(13, 30, 0), (87, 25, 1.7), (86, 70, 3.1), (14, 72, 4.4)]
        for spot in spots {
            let k = 0.5 + 0.5 * sin(phase * 3 + spot.2)
            ctx.fill(star(CGPoint(x: spot.0, y: spot.1), 2.5 + 3.5 * k), with: .color(Palette.gold.opacity(0.4 + 0.6 * k)))
        }
    }

    private static func drawConfetti(_ ctx: GraphicsContext, _ phase: Double) {
        let colors: [Color] = [Palette.gold, Palette.teal, Palette.coral, OrevColors.amberLight, Palette.sage]
        for i in 0..<14 {
            let seed = Double(i)
            let x = 8 + (seed * 37).truncatingRemainder(dividingBy: 84)
            let speed = 18 + (seed * 13).truncatingRemainder(dividingBy: 14)
            let y = (phase * speed + seed * 23).truncatingRemainder(dividingBy: 72) - 2
            var c = ctx
            c.translateBy(x: x + sin(phase * 2 + seed) * 3, y: y)
            c.rotate(by: .radians(phase * 3 + seed))
            c.fill(Path(CGRect(x: -1.6, y: -0.9, width: 3.2, height: 1.8)), with: .color(colors[i % colors.count]))
        }
    }

    private static func drawSweat(_ ctx: GraphicsContext, _ phase: Double) {
        let dy = phase.truncatingRemainder(dividingBy: 2.4) / 2.4 * 5
        var drop = Path()
        drop.move(to: CGPoint(x: 76, y: 22 + dy))
        drop.addQuadCurve(to: CGPoint(x: 76, y: 31 + dy), control: CGPoint(x: 81, y: 29 + dy))
        drop.addQuadCurve(to: CGPoint(x: 76, y: 22 + dy), control: CGPoint(x: 71, y: 29 + dy))
        ctx.fill(drop, with: .color(Palette.teal.opacity(0.75)))
    }

    private static func drawListening(_ ctx: GraphicsContext, _ phase: Double) {
        for i in 0..<2 {
            let k = (phase + Double(i) * 0.5).truncatingRemainder(dividingBy: 1)
            var arc = Path()
            arc.addArc(center: CGPoint(x: 80, y: 38), radius: 6 + k * 10, startAngle: .degrees(-50), endAngle: .degrees(50), clockwise: false)
            ctx.stroke(arc, with: .color(Palette.teal.opacity(1 - k)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        }
    }
}
