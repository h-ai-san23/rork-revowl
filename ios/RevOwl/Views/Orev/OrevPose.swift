import CoreGraphics
import Foundation

/// A single frame of Orev's body language, derived from a state and time.
struct OrevPose {
    enum Brows { case flat, curious, worried }

    var bob: CGFloat = 0
    var tilt: Double = 0
    var eyeOpen: CGFloat = 1
    var eyeScale: CGFloat = 1
    var pupil: CGSize = .zero
    var leftWing: Double = 0
    var rightWing: Double = 0
    var beakOpen: CGFloat = 0
    var earLift: CGFloat = 0
    var glow: Double = 0
    var happyEyes = false
    var brows: Brows = .flat
    var browRaise: CGFloat = 0
    var dotsPhase: Double?
    var questionPhase: Double?
    var sparklePhase: Double?
    var confettiPhase: Double?
    var sweatPhase: Double?
    var listenPhase: Double?

    static func make(_ state: OrevState, t: Double, animated: Bool) -> OrevPose {
        var p = OrevPose()
        if animated {
            p.bob = CGFloat(sin(t * 1.7) * 1.1)
            p.eyeOpen = blink(t)
            p.pupil = CGSize(width: sin(t * 0.37) * 1.1, height: cos(t * 0.29) * 0.6)
        }
        switch state {
        case .idle:
            break
        case .welcome:
            p.rightWing = 75 + (animated ? sin(t * 7) * 22 : 0)
            p.tilt = -4
            p.earLift = 2
            p.bob = animated ? CGFloat(sin(t * 3) * 1.6) : 0
        case .listening:
            p.tilt = 9
            p.eyeScale = 1.08
            p.earLift = 3
            p.pupil = CGSize(width: 1.6, height: 0)
            p.listenPhase = animated ? (t.truncatingRemainder(dividingBy: 1.6) / 1.6) : 0.4
        case .thinking:
            p.tilt = -6
            p.pupil = CGSize(width: 2.4, height: -2.6)
            p.rightWing = 20
            p.dotsPhase = animated ? t : 0
        case .explaining:
            p.beakOpen = animated ? CGFloat(max(0, sin(t * 10)) * 0.8) : 0.4
            p.leftWing = 32 + (animated ? sin(t * 2.2) * 14 : 0)
            p.tilt = animated ? sin(t * 1.3) * 3 : 0
        case .opportunity:
            p.glow = animated ? 0.75 + 0.25 * sin(t * 2.4) : 0.9
            p.eyeScale = 1.1
            p.earLift = 2.5
            p.sparklePhase = animated ? t : 0.3
            p.bob = animated ? CGFloat(sin(t * 2.6) * 1.8) : 0
        case .uncertainty:
            p.tilt = 13 + (animated ? sin(t * 1.1) * 2 : 0)
            p.brows = .curious
            p.browRaise = 3
            p.pupil = CGSize(width: -2, height: -1)
            p.questionPhase = animated ? t : 0
        case .celebrating:
            p.bob = animated ? -CGFloat(abs(sin(t * 5.5)) * 6) : -2
            p.leftWing = 100 + (animated ? sin(t * 11) * 12 : 0)
            p.rightWing = 100 + (animated ? cos(t * 11) * 12 : 0)
            p.happyEyes = true
            p.earLift = 3
            p.confettiPhase = animated ? t : 0.4
        case .errorRecovery:
            p.eyeOpen = min(p.eyeOpen, 0.62)
            p.tilt = -7
            p.leftWing = -6
            p.rightWing = -6
            p.brows = .worried
            p.sweatPhase = animated ? t : 0.5
            p.bob = animated ? CGFloat(sin(t * 1.1) * 1.8) : 0
        }
        return p
    }

    /// Quick blink roughly every four seconds.
    static func blink(_ t: Double) -> CGFloat {
        let c = t.truncatingRemainder(dividingBy: 4.3)
        guard c < 0.16 else { return 1 }
        return CGFloat(abs(c - 0.08) / 0.08) * 0.9 + 0.1
    }
}
