import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var currentPage: Int = 0
    @State private var animateCards = false
    @State private var animateChart = false

    var body: some View {
        ZStack {
            DeepGlassBackground()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    competingBlindPage.tag(0)
                    meetOwlPage.tag(1)
                    dynamicPricingPage.tag(2)
                    disclaimerPage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.smooth, value: currentPage)

                bottomSection
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                animateCards = true
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                animateChart = true
            }
        }
    }



    private var competingBlindPage: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    competitorCard(
                        name: ["Hilton", "Marriott", "Hyatt"][index],
                        rate: ["$179", "$195", "$189"][index],
                        change: ["+4.1%", "-2.3%", "+6.5%"][index]
                    )
                    .offset(
                        x: animateCards ? CGFloat(index - 1) * 15 : CGFloat(index - 1) * 8,
                        y: CGFloat(index) * 14 + (animateCards ? -4 : 4)
                    )
                    .rotationEffect(.degrees(Double(index - 1) * (animateCards ? 3 : -2)))
                    .opacity(0.95 - Double(index) * 0.1)
                }

                VStack(spacing: 4) {
                    Text("Your Rate")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("$169")
                        .font(.title.bold())
                        .foregroundStyle(RevOwlTheme.gold)
                        .shadow(color: RevOwlTheme.gold.opacity(0.3), radius: 8)
                    Text("unchanged")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(20)
                .glassCardStyle(cornerRadius: 16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(RevOwlTheme.gold.opacity(0.25), lineWidth: 1)
                )
                .offset(y: 100)
            }
            .frame(height: 260)

            VStack(spacing: 12) {
                Text("You're Competing Blind")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Your competitors change rates 14×/day.\nDo you know what they charge right now?")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private var meetOwlPage: some View {
        VStack(spacing: 32) {
            Spacer()

            OwlMascotView(size: 140)

            VStack(spacing: 12) {
                Text("Meet Your Revenue Owl")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("RevOwl watches the market 24/7\nso you don't have to.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 24)

            HStack(spacing: 16) {
                signalPill(icon: "chart.line.uptrend.xyaxis", text: "Rates")
                signalPill(icon: "flame.fill", text: "Demand")
                signalPill(icon: "brain.fill", text: "AI Rec")
            }

            Spacer()
        }
    }

    private var dynamicPricingPage: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(0..<7, id: \.self) { i in
                        let baseHeight: CGFloat = 40 + CGFloat(i) * 12
                        let animatedHeight = animateChart ? baseHeight + 20 : baseHeight - 10
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [RevOwlTheme.gold.opacity(0.2), RevOwlTheme.gold],
                                    startPoint: .bottom, endPoint: .top
                                )
                            )
                            .frame(width: 30, height: max(animatedHeight, 20))
                            .shadow(color: RevOwlTheme.gold.opacity(0.2), radius: 4, y: -2)
                            .animation(
                                .easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(Double(i) * 0.1),
                                value: animateChart
                            )
                    }
                }
                .frame(height: 160)

                HStack {
                    ForEach(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], id: \.self) { day in
                        Text(day)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 30)
                    }
                }
            }
            .padding(.horizontal, 32)

            VStack(spacing: 12) {
                Text("Dynamic Pricing, Simplified")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("AI rates that fill rooms\nand maximize revenue.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private var disclaimerPage: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(RevOwlTheme.gold.opacity(0.06))
                    .frame(width: 180, height: 180)
                Circle()
                    .fill(RevOwlTheme.gold.opacity(0.03))
                    .frame(width: 240, height: 240)
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(RevOwlTheme.gold)
                    .shadow(color: RevOwlTheme.gold.opacity(0.4), radius: 16)
            }

            VStack(spacing: 16) {
                Text("Important Disclaimer")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("RevOwl is a standalone tool designed to assist hotel owners and managers with revenue management decisions.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Text("All recommendations, rate suggestions, occupancy inputs, and pricing adjustments are provided as guidance only. Any changes made based on this app's recommendations are at the user's sole discretion and responsibility.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Text("Future updates may include automated rate management, but for now all actions require manual implementation by the user.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 28)

            HStack(spacing: 12) {
                disclaimerPill(icon: "hand.raised.fill", text: "User Discretion")
                disclaimerPill(icon: "wrench.and.screwdriver.fill", text: "Manual Actions")
            }

            Spacer()
        }
    }

    private func disclaimerPill(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(.white.opacity(0.95))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassCardStyle(cornerRadius: 20, elevation: .subtle)
    }

    private var bottomSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(index == currentPage ? RevOwlTheme.gold : .white.opacity(0.2))
                        .frame(width: index == currentPage ? 24 : 8, height: 8)
                        .shadow(color: index == currentPage ? RevOwlTheme.gold.opacity(0.4) : .clear, radius: 4)
                        .animation(.snappy, value: currentPage)
                }
            }

            if currentPage == 3 {
                VStack(spacing: 12) {
                    Button(action: onComplete) {
                        HStack {
                            Text("Set Up My Hotel")
                            Image(systemName: "arrow.right")
                        }
                    }
                    .buttonStyle(GoldButtonStyle())

                    Button("Explore Free Tier") {
                        onComplete()
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                }
                .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
            } else {
                Button {
                    withAnimation(.snappy) { currentPage += 1 }
                } label: {
                    HStack {
                        Text("Continue")
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(GlassButtonStyle())
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
        .animation(.smooth, value: currentPage)
    }

    private func competitorCard(name: String, rate: String, change: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                Text("King Room")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.75))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(rate)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(change)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(change.hasPrefix("+") ? RevOwlTheme.positive : change.hasPrefix("-") ? RevOwlTheme.negative : .white.opacity(0.4))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 220)
        .glassCardStyle(cornerRadius: 14, elevation: .subtle)
    }

    private func signalPill(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(.white.opacity(0.95))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassCardStyle(cornerRadius: 20, elevation: .subtle)
    }
}
