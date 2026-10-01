import SwiftUI

struct RoomsStep: View {
    @Environment(AppModel.self) private var app
    @State private var rooms = ""
    @State private var isWorking = false
    @State private var errorText: String?

    private var value: Int? {
        guard let n = Int(rooms.trimmed), (1...10_000).contains(n) else { return nil }
        return n
    }

    var body: some View {
        StepScaffold(
            orev: isWorking ? .thinking : .listening,
            title: "How many rooms can you sell?",
            message: "Your total sellable rooms (keys) on a normal night. I use this as “rooms available” when a report doesn't include it.",
            primaryEnabled: value != nil,
            isWorking: isWorking,
            onPrimary: { Task { await save() } }
        ) {
            VStack(spacing: 14) {
                HStack(spacing: 16) {
                    Button { adjust(-1) } label: {
                        Image(systemName: "minus").font(.title3.weight(.semibold)).frame(width: 52, height: 52)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Fewer rooms")
                    .accessibilityIdentifier("rooms.minus")

                    AppTextField(
                        placeholder: "0",
                        text: $rooms,
                        id: "rooms.count",
                        keyboard: .numberPad,
                        font: .system(.largeTitle, design: .serif, weight: .bold),
                        alignment: .center,
                        accessibilityLabel: "Number of rooms"
                    )
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity)

                    Button { adjust(1) } label: {
                        Image(systemName: "plus").font(.title3.weight(.semibold)).frame(width: 52, height: 52)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("More rooms")
                    .accessibilityIdentifier("rooms.plus")
                }
                Text("rooms").font(.subheadline).foregroundStyle(Palette.inkTertiary)
            }
            .card(padding: 20)
            .sensoryFeedback(.selection, trigger: rooms)

            if let extracted = app.extraction?.fields.roomCount, app.profile?.roomCount == nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your website mentions \(Int(extracted.value)) rooms. Please confirm this is your total sellable inventory.")
                        .font(.subheadline).foregroundStyle(Palette.ink)
                    FieldSourceNote(confidence: extracted.confidence, evidence: extracted.evidence)
                }
                .card(fill: Palette.surfaceRaised)
            }
            if let errorText { InlineMessage(kind: .error, text: errorText) }
        }
        .onAppear {
            guard rooms.isEmpty else { return }
            if let r = app.profile?.roomCount ?? app.extraction?.fields.roomCount.map({ Int($0.value) }) { rooms = String(r) }
        }
    }

    private func adjust(_ delta: Int) {
        let n = max(1, min(10_000, (Int(rooms) ?? 0) + delta))
        rooms = String(n)
    }

    private func save() async {
        guard let value else { return }
        isWorking = true
        errorText = nil
        defer { isWorking = false }
        var body: [String: JSONValue] = ["roomCount": .number(Double(value))]
        if let ex = app.extraction?.fields.roomCount, Int(ex.value) == value, let url = app.extraction?.sourceUrl {
            body["fieldSources"] = ["roomCount": ["source": "website", "confidence": .string(ex.confidence), "url": .string(url)]]
        }
        do {
            try await app.updateProfile(body)
            app.goTo(.locale)
        } catch {
            errorText = error.userMessage
        }
    }
}
