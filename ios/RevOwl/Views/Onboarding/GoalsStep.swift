import SwiftUI

struct GoalsStep: View {
    @Environment(AppModel.self) private var app
    @State private var selected: [String] = []
    @State private var isWorking = false
    @State private var errorText: String?
    @State private var loaded = false

    var body: some View {
        StepScaffold(
            orev: selected.isEmpty ? .listening : .explaining,
            title: "What matters most right now?",
            message: "Pick up to four. I'll lead with these in your briefings.",
            primaryEnabled: !selected.isEmpty,
            isWorking: isWorking,
            onPrimary: { Task { await save() } }
        ) {
            VStack(spacing: 10) {
                ForEach(GoalOption.all) { goal in
                    let on = selected.contains(goal.id)
                    Button {
                        if on {
                            selected.removeAll { $0 == goal.id }
                        } else if selected.count < 4 {
                            selected.append(goal.id)
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: goal.icon)
                                .font(.title3)
                                .foregroundStyle(on ? Palette.onAccent : Palette.teal)
                                .frame(width: 40, height: 40)
                                .background(on ? Palette.teal : Palette.tealSoft, in: .circle)
                            Text(goal.title).font(.headline).foregroundStyle(Palette.ink)
                            Spacer()
                            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(on ? Palette.teal : Palette.hairline)
                        }
                        .padding(14)
                        .background(Palette.surface, in: .rect(cornerRadius: Metrics.smallRadius))
                        .overlay {
                            RoundedRectangle(cornerRadius: Metrics.smallRadius)
                                .strokeBorder(on ? Palette.teal : Palette.hairline, lineWidth: on ? 2 : 1)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                    .accessibilityIdentifier("goal.\(goal.id)")
                }
            }
            .sensoryFeedback(.selection, trigger: selected)
            if let errorText { InlineMessage(kind: .error, text: errorText) }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            selected = app.profile?.goals ?? []
        }
    }

    private func save() async {
        isWorking = true
        errorText = nil
        defer { isWorking = false }
        do {
            try await app.updateProfile(["goals": .from(selected)])
            app.goTo(.overview)
        } catch {
            errorText = error.userMessage
        }
    }
}
