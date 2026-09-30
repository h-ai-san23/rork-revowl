import SwiftUI

/// Resumable onboarding. Steps from "Website" onward are saved to the property on the server,
/// so closing the app mid-setup returns the user to the same step.
struct OnboardingFlow: View {
    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            if app.onboardingStep.isServerStep {
                OnboardingHeader()
            }
            stepView
                .id(app.onboardingStep)
                .transition(reduceMotion ? .opacity : .asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .opacity
                ))
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(.smooth(duration: 0.35), value: app.onboardingStep)
    }

    @ViewBuilder
    private var stepView: some View {
        switch app.onboardingStep {
        case .welcome: WelcomeStep()
        case .signIn: SignInStep()
        case .property: PropertyStep()
        case .website: WebsiteStep()
        case .confirm: ConfirmDetailsStep()
        case .rooms: RoomsStep()
        case .locale: LocaleStep()
        case .dataImport: ImportStep()
        case .competitors: CompetitorsStep()
        case .goals: GoalsStep()
        case .overview: OverviewStep()
        case .plans: PlansStep()
        case .briefing: FirstBriefingStep()
        }
    }
}

private struct OnboardingHeader: View {
    @Environment(AppModel.self) private var app

    private var progress: Double {
        let first = OnboardingStep.website.index
        let last = OnboardingStep.briefing.index
        return Double(app.onboardingStep.index - first + 1) / Double(last - first + 1)
    }

    private var stepLabel: String {
        let first = OnboardingStep.website.index
        let count = OnboardingStep.briefing.index - first + 1
        return "Step \(app.onboardingStep.index - first + 1) of \(count) · \(app.onboardingStep.shortTitle)"
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                if let previous = app.onboardingStep.previous {
                    Button {
                        app.goTo(previous)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Back to \(previous.shortTitle)")
                } else {
                    Color.clear.frame(width: 44, height: 44)
                }
                Spacer()
                Text(stepLabel)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.inkSecondary)
                Spacer()
                Menu {
                    if (app.me?.properties.count ?? 0) > 1 {
                        ForEach(app.me?.properties ?? []) { p in
                            Button(p.name) { Task { try? await app.selectProperty(p.propertyId) } }
                        }
                        Divider()
                    }
                    Button("Sign out", role: .destructive) { Task { await app.signOut() } }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("More options")
            }
            ProgressView(value: progress)
                .tint(Palette.teal)
                .accessibilityLabel("Setup progress")
                .accessibilityValue(stepLabel)
        }
        .padding(.horizontal, Metrics.margin)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }
}
