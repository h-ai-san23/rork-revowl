import SwiftUI

struct WelcomeStep: View {
    @Environment(AppModel.self) private var app
    @State private var appeared = false

    private let points: [(String, String, String)] = [
        ("sun.horizon", "A daily briefing", "What changed, what matters today, and why."),
        ("chart.bar.xaxis", "Numbers you can trust", "Occupancy, ADR and RevPAR calculated from your data — never guessed."),
        ("binoculars", "Your market, watched", "Public competitor rates and local events, with sources."),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                OrevView(state: .welcome, size: 190)
                    .padding(.top, 24)
                    .scaleEffect(appeared ? 1 : 0.85)
                    .opacity(appeared ? 1 : 0)

                VStack(spacing: 10) {
                    Text("Hi, I'm Orev.")
                        .font(.display(.largeTitle, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    Text("I'm the revenue consultant inside revOWL. I read your numbers, watch your market and tell you what's worth your attention.")
                        .font(.body)
                        .foregroundStyle(Palette.inkSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    ForEach(points, id: \.0) { point in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: point.0)
                                .font(.title3)
                                .foregroundStyle(Palette.teal)
                                .frame(width: 40, height: 40)
                                .background(Palette.tealSoft, in: .circle)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(point.1).font(.headline).foregroundStyle(Palette.ink)
                                Text(point.2).font(.subheadline).foregroundStyle(Palette.inkSecondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .card()
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            Button("Get started") { app.goTo(.signIn) }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("welcome.start")
                .padding(.horizontal, Metrics.margin)
                .padding(.bottom, 8)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.7, bounce: 0.35)) { appeared = true }
        }
    }
}
