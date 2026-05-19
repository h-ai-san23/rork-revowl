import SwiftUI

enum RevOwlTheme {
    static let navy = Color(red: 11/255, green: 29/255, blue: 58/255)
    static let gold = Color(red: 245/255, green: 166/255, blue: 35/255)
    static let darkNavy = Color(red: 5/255, green: 13/255, blue: 26/255)
    static let midNavy = Color(red: 8/255, green: 20/255, blue: 42/255)
    static let lightNavy = Color(red: 22/255, green: 48/255, blue: 90/255)
    static let goldLight = Color(red: 255/255, green: 200/255, blue: 100/255)

    static let positive = Color(red: 16/255, green: 185/255, blue: 129/255)
    static let negative = Color(red: 239/255, green: 68/255, blue: 68/255)
    static let demandGreen = Color(red: 16/255, green: 185/255, blue: 129/255)
    static let demandAmber = Color(red: 245/255, green: 166/255, blue: 35/255)
    static let demandRed = Color(red: 239/255, green: 68/255, blue: 68/255)

    static let occupancyLow = Color(red: 239/255, green: 68/255, blue: 68/255)
    static let occupancyMid = Color(red: 245/255, green: 166/255, blue: 35/255)
    static let occupancyHigh = Color(red: 16/255, green: 185/255, blue: 129/255)

    static func demandColor(for score: Int) -> Color {
        if score < 40 { return demandGreen }
        if score < 70 { return demandAmber }
        return demandRed
    }

    static func occupancyColor(for percentage: Double) -> Color {
        if percentage < 0.4 { return occupancyLow }
        if percentage < 0.8 { return occupancyMid }
        return occupancyHigh
    }

    static let goldGradient = LinearGradient(
        colors: [gold, goldLight],
        startPoint: .leading,
        endPoint: .trailing
    )
}

struct DeepGlassBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            if true {
                MeshGradient(
                    width: 3, height: 3,
                    points: [
                        [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                        [0.0, 0.5], [0.5, 0.4 + Float(sin(phase)) * 0.06], [1.0, 0.5],
                        [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
                    ],
                    colors: [
                        RevOwlTheme.darkNavy,
                        Color(red: 0.03, green: 0.06, blue: 0.14),
                        RevOwlTheme.darkNavy,
                        Color(red: 0.04, green: 0.07, blue: 0.16),
                        RevOwlTheme.midNavy,
                        Color(red: 0.03, green: 0.06, blue: 0.14),
                        RevOwlTheme.darkNavy,
                        Color(red: 0.04, green: 0.08, blue: 0.18),
                        RevOwlTheme.darkNavy
                    ]
                )
                RadialGradient(
                    colors: [
                        RevOwlTheme.gold.opacity(0.06),
                        RevOwlTheme.gold.opacity(0.02),
                        .clear
                    ],
                    center: .init(x: 0.5, y: 0.25),
                    startRadius: 0,
                    endRadius: 500
                )
            } else {
                MeshGradient(
                    width: 3, height: 3,
                    points: [
                        [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                        [0.0, 0.5], [0.5, 0.4 + Float(sin(phase)) * 0.04], [1.0, 0.5],
                        [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
                    ],
                    colors: [
                        Color(red: 0.96, green: 0.95, blue: 0.93),
                        Color(red: 0.94, green: 0.93, blue: 0.91),
                        Color(red: 0.96, green: 0.95, blue: 0.94),
                        Color(red: 0.93, green: 0.92, blue: 0.90),
                        Color(red: 0.95, green: 0.94, blue: 0.92),
                        Color(red: 0.94, green: 0.93, blue: 0.91),
                        Color(red: 0.96, green: 0.95, blue: 0.93),
                        Color(red: 0.93, green: 0.92, blue: 0.91),
                        Color(red: 0.95, green: 0.94, blue: 0.93)
                    ]
                )
                RadialGradient(
                    colors: [
                        RevOwlTheme.gold.opacity(0.08),
                        RevOwlTheme.gold.opacity(0.03),
                        .clear
                    ],
                    center: .init(x: 0.5, y: 0.2),
                    startRadius: 0,
                    endRadius: 400
                )
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                phase = .pi * 2
            }
        }
    }
}

struct GlassCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat
    let elevation: GlassElevation
    @ViewBuilder let content: () -> Content

    init(cornerRadius: CGFloat = 20, elevation: GlassElevation = .primary, @ViewBuilder content: @escaping () -> Content) {
        self.cornerRadius = cornerRadius
        self.elevation = elevation
        self.content = content
    }

    var body: some View {
        content()
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(colorScheme == .dark ? elevation.fillTop : elevation.fillTop * 0.5),
                                        RevOwlTheme.gold.opacity(0.015),
                                        .white.opacity(colorScheme == .dark ? elevation.fillBottom : elevation.fillBottom * 0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(colorScheme == .dark ? elevation.borderTop : elevation.borderTop * 0.7),
                                        .white.opacity(colorScheme == .dark ? elevation.borderBottom : elevation.borderBottom * 0.5)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: colorScheme == .dark ? 0.8 : 0.5
                            )
                    )
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(colorScheme == .dark ? 0.06 : 0.12), .clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                            .allowsHitTesting(false)
                    }
                    .shadow(
                        color: colorScheme == .dark
                            ? .black.opacity(elevation.shadowOpacity)
                            : .black.opacity(elevation.shadowOpacity * 0.35),
                        radius: elevation.shadowRadius,
                        y: elevation.shadowY
                    )
            }
    }
}

enum GlassElevation {
    case primary
    case elevated
    case subtle

    var fillTop: CGFloat {
        switch self {
        case .primary: return 0.12
        case .elevated: return 0.18
        case .subtle: return 0.08
        }
    }
    var fillBottom: CGFloat {
        switch self {
        case .primary: return 0.06
        case .elevated: return 0.10
        case .subtle: return 0.04
        }
    }
    var borderTop: CGFloat {
        switch self {
        case .primary: return 0.25
        case .elevated: return 0.35
        case .subtle: return 0.18
        }
    }
    var borderBottom: CGFloat {
        switch self {
        case .primary: return 0.06
        case .elevated: return 0.10
        case .subtle: return 0.04
        }
    }
    var shadowOpacity: CGFloat {
        switch self {
        case .primary: return 0.25
        case .elevated: return 0.4
        case .subtle: return 0.15
        }
    }
    var shadowRadius: CGFloat {
        switch self {
        case .primary: return 16
        case .elevated: return 24
        case .subtle: return 8
        }
    }
    var shadowY: CGFloat {
        switch self {
        case .primary: return 6
        case .elevated: return 10
        case .subtle: return 3
        }
    }
}

extension View {
    func glassCardStyle(cornerRadius: CGFloat = 20, elevation: GlassElevation = .primary) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, elevation: elevation))
    }

    func deepGlassBackground() -> some View {
        self.background { DeepGlassBackground() }
    }

    func glassPress(isPressed: Bool) -> some View {
        self
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }
}

struct GlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat
    let elevation: GlassElevation

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(colorScheme == .dark ? elevation.fillTop : elevation.fillTop * 0.5),
                                        RevOwlTheme.gold.opacity(0.015),
                                        .white.opacity(colorScheme == .dark ? elevation.fillBottom : elevation.fillBottom * 0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(colorScheme == .dark ? elevation.borderTop : elevation.borderTop * 0.7),
                                        .white.opacity(colorScheme == .dark ? elevation.borderBottom : elevation.borderBottom * 0.5)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: colorScheme == .dark ? 0.8 : 0.5
                            )
                    )
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(colorScheme == .dark ? 0.06 : 0.12), .clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                            .allowsHitTesting(false)
                    }
                    .shadow(
                        color: colorScheme == .dark
                            ? .black.opacity(elevation.shadowOpacity)
                            : .black.opacity(elevation.shadowOpacity * 0.35),
                        radius: elevation.shadowRadius,
                        y: elevation.shadowY
                    )
            }
    }
}

struct GoldButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(RevOwlTheme.goldGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.25), .clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                    )
            }
            .shadow(color: RevOwlTheme.gold.opacity(0.35), radius: 12, y: 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .glassCardStyle(cornerRadius: 14, elevation: .subtle)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct GlassChipStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                if isActive {
                    Capsule()
                        .fill(RevOwlTheme.gold.opacity(0.25))
                        .overlay(
                            Capsule()
                                .strokeBorder(RevOwlTheme.gold.opacity(0.5), lineWidth: 1)
                        )
                        .shadow(color: RevOwlTheme.gold.opacity(0.15), radius: 6, y: 2)
                } else {
                    Capsule()
                        .fill(.thinMaterial)
                        .overlay(
                            Capsule()
                                .strokeBorder(.primary.opacity(0.1), lineWidth: 0.5)
                        )
                }
            }
            .foregroundStyle(isActive ? RevOwlTheme.gold : .secondary)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct GlassPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct StaggeredAppearModifier: ViewModifier {
    let index: Int
    let appear: Bool

    func body(content: Content) -> some View {
        content
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 20)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.05),
                value: appear
            )
    }
}

extension View {
    func staggeredAppear(index: Int, appear: Bool) -> some View {
        modifier(StaggeredAppearModifier(index: index, appear: appear))
    }
}
