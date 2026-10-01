import SwiftUI

private struct ChatMessage: Identifiable, Hashable {
    let id: String
    let isUser: Bool
    let text: String
    var mood: String = "explaining"
    var evidence: [AskEvidence] = []
    var followUps: [String] = []
}

struct AskView: View {
    @Environment(AppModel.self) private var app
    @State private var messages: [ChatMessage] = []
    @State private var draft = ""
    @State private var isThinking = false
    @State private var errorText: String?
    @State private var usage: AskUsage?
    @State private var loadedFor: String?
    @FocusState private var focused: Bool

    private let starters = ["How did last week go?", "Which upcoming dates look soft?", "Am I priced well against competitors?", "What events should I plan for?"]

    private var orevState: OrevState {
        if isThinking { return .thinking }
        if errorText != nil { return .errorRecovery }
        if focused { return .listening }
        return messages.last.map { OrevState(mood: $0.mood) } ?? .welcome
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    OrevBubble(
                        state: orevState,
                        title: messages.isEmpty ? "Ask me anything about your property" : orevState.statusText,
                        message: messages.isEmpty ? "I answer from your data, public rates and your calendar — and I'll tell you when something's missing." : nil,
                        size: messages.isEmpty ? 96 : 56
                    )
                    if messages.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(starters, id: \.self) { q in
                                Button(q) { send(q) }
                                    .buttonStyle(ChipButtonStyle())
                                    .accessibilityIdentifier("ask.starter")
                            }
                        }
                    }
                    ForEach(messages) { m in
                        MessageBubble(message: m) { send($0) }
                            .id(m.id)
                    }
                    if isThinking {
                        HStack(spacing: 10) {
                            OrevView(state: .thinking, size: 40)
                            Text("Checking your data…").font(.subheadline).foregroundStyle(Palette.inkSecondary)
                        }
                        .id("thinking")
                    }
                    if let errorText {
                        InlineMessage(kind: .error, text: errorText, actionTitle: errorPlanAction ? "See plans" : nil) {
                            app.showPaywall = true
                        }
                        .id("error")
                    }
                }
                .padding(.horizontal, Metrics.margin)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) { _, _ in
                withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
            }
            .onChange(of: isThinking) { _, thinking in
                if thinking { withAnimation { proxy.scrollTo("thinking", anchor: .bottom) } }
            }
        }
        .background(AppBackground())
        .navigationTitle("Ask Orev")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let usage {
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(max(0, usage.allowed - usage.used)) left")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.inkSecondary)
                        .accessibilityLabel("\(max(0, usage.allowed - usage.used)) Orev answers left this period")
                }
            }
        }
        .safeAreaInset(edge: .bottom) { composer }
        .task(id: app.propertyId) { await loadHistory() }
        .onChange(of: app.pendingQuestion, initial: true) { _, q in
            guard let q else { return }
            app.pendingQuestion = nil
            send(q)
        }
    }

    private var errorPlanAction: Bool { errorText?.contains("plan") == true || errorText?.contains("trial") == true }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask about rates, pace, events…", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .focused($focused)
                .submitLabel(.send)
                .onSubmit { send(draft) }
                .accessibilityIdentifier("ask.input")
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .background {
                    // Taps in the padding around the text focus the field too.
                    Color.clear
                        .contentShape(.rect(cornerRadius: 24))
                        .onTapGesture { focused = true }
                }
                .glassEffect(.regular, in: .rect(cornerRadius: 24))
            Button {
                send(draft)
            } label: {
                Image(systemName: "arrow.up")
                    .font(.headline)
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(.glassProminent)
            .tint(Palette.teal)
            .disabled(draft.trimmed.isEmpty || isThinking)
            .accessibilityLabel("Send")
            .accessibilityIdentifier("ask.send")
        }
        .padding(.horizontal, Metrics.margin)
        .padding(.vertical, 8)
    }

    private func loadHistory() async {
        guard let id = app.propertyId, loadedFor != id else { return }
        loadedFor = id
        if let res: AskHistoryResponse = try? await app.api.get(app.path("/ask/history")) {
            let history = res.items.suffix(12).flatMap { item in
                [ChatMessage(id: "\(item.id)-q", isUser: true, text: item.question),
                 ChatMessage(id: item.id, isUser: false, text: item.answer, mood: item.mood, evidence: item.evidence)]
            }
            // A question may already be in flight (e.g. sent from Today); keep it after the history.
            let known = Set(history.map(\.id))
            messages = history + messages.filter { !known.contains($0.id) }
        }
        if let u: UsageInfo = try? await app.api.get(app.path("/usage")) {
            usage = AskUsage(used: u.orevAnswersUsed, allowed: u.orevAnswersAllowed)
        }
    }

    private func send(_ raw: String) {
        let q = raw.trimmed
        guard !q.isEmpty, !isThinking else { return }
        draft = ""
        errorText = nil
        let history = messages.suffix(8).map { AskTurn(role: $0.isUser ? "user" : "orev", text: $0.text) }
        messages.append(ChatMessage(id: UUID().uuidString, isUser: true, text: q))
        isThinking = true
        Task {
            defer { isThinking = false }
            do {
                let historyJSON: [JSONValue] = history.map { ["role": .string($0.role), "text": .string($0.text)] }
                let res: AskResponse = try await app.api.post(app.path("/ask"), json: ["question": .string(q), "history": .array(historyJSON)])
                messages.append(ChatMessage(id: res.id, isUser: false, text: res.answer, mood: res.mood, evidence: res.evidence, followUps: res.followUps))
                usage = res.usage
            } catch {
                errorText = error.userMessage
            }
        }
    }
}

private struct MessageBubble: View {
    let message: ChatMessage
    var onFollowUp: (String) -> Void

    var body: some View {
        if message.isUser {
            HStack {
                Spacer(minLength: 48)
                Text(message.text)
                    .font(.body)
                    .foregroundStyle(Palette.onAccent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Palette.teal, in: .rect(cornerRadius: 18))
            }
            .accessibilityLabel("You asked: \(message.text)")
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text(message.text)
                    .font(.body)
                    .foregroundStyle(Palette.ink)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                if !message.evidence.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Based on").font(.caption.weight(.semibold)).foregroundStyle(Palette.inkTertiary)
                        ForEach(message.evidence, id: \.summary) { e in
                            HStack(spacing: 6) {
                                BasisBadge(basis: e.basis)
                                Text(e.summary).font(.caption).foregroundStyle(Palette.inkSecondary)
                            }
                        }
                    }
                }
                if !message.followUps.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(message.followUps, id: \.self) { f in
                                Button(f) { onFollowUp(f) }.buttonStyle(ChipButtonStyle())
                            }
                        }
                    }
                    .scrollClipDisabled()
                }
            }
            .card(padding: 14)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Orev answered")
        }
    }
}
