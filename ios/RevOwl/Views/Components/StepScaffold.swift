import SwiftUI

/// Shared layout for onboarding steps: Orev + message, scrollable content, pinned actions.
struct StepScaffold<Content: View>: View {
    let orev: OrevState
    let title: String
    let message: String
    let primaryTitle: String
    let primaryEnabled: Bool
    let isWorking: Bool
    let secondaryTitle: String?
    let onPrimary: () -> Void
    let onSecondary: (() -> Void)?
    let content: Content

    init(
        orev: OrevState,
        title: String,
        message: String,
        primaryTitle: String = "Continue",
        primaryEnabled: Bool = true,
        isWorking: Bool = false,
        secondaryTitle: String? = nil,
        onPrimary: @escaping () -> Void,
        onSecondary: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.orev = orev
        self.title = title
        self.message = message
        self.primaryTitle = primaryTitle
        self.primaryEnabled = primaryEnabled
        self.isWorking = isWorking
        self.secondaryTitle = secondaryTitle
        self.onPrimary = onPrimary
        self.onSecondary = onSecondary
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                OrevBubble(state: orev, title: title, message: message)
                content
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                Button(action: onPrimary) {
                    if isWorking {
                        ProgressView().tint(Palette.onAccent)
                    } else {
                        Text(primaryTitle)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!primaryEnabled || isWorking)
                .sensoryFeedback(.impact(weight: .light), trigger: isWorking)

                if let secondaryTitle, let onSecondary {
                    Button(secondaryTitle, action: onSecondary)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.teal)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .disabled(isWorking)
                }
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.top, 12)
            .padding(.bottom, 6)
            .background {
                Palette.canvasDeep.opacity(0.96)
                    .ignoresSafeArea()
                    .overlay(alignment: .top) { Divider().overlay(Palette.hairline) }
            }
        }
    }
}
