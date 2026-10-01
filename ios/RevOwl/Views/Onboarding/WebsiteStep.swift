import SwiftUI

struct WebsiteStep: View {
    @Environment(AppModel.self) private var app
    @State private var url = ""
    @State private var isWorking = false
    @State private var errorText: String?

    var body: some View {
        StepScaffold(
            orev: isWorking ? .thinking : (errorText != nil ? .errorRecovery : .explaining),
            title: "Can I read your website?",
            message: "I'll pull public details like your address and amenities so you don't have to type them. You'll review everything before it's saved.",
            primaryTitle: "Read my website",
            primaryEnabled: url.trimmed.count >= 4,
            isWorking: isWorking,
            secondaryTitle: "Skip — I'll enter details myself",
            onPrimary: { Task { await extract() } },
            onSecondary: { app.goTo(.confirm) }
        ) {
            AppTextField(
                placeholder: "yourhotel.com",
                text: $url,
                id: "website.url",
                icon: "globe",
                keyboard: .URL,
                contentType: .URL,
                capitalization: .never,
                autocorrect: false,
                submitLabel: .go,
                accessibilityLabel: "Website address",
                onSubmit: { Task { await extract() } }
            )

            if isWorking {
                InlineMessage(kind: .info, text: "Reading your website. This can take up to 30 seconds.")
            }
            if let errorText {
                InlineMessage(kind: .error, text: errorText)
            }

            VStack(alignment: .leading, spacing: 10) {
                Label("What I'll look for", systemImage: "checkmark.circle")
                    .font(.headline).foregroundStyle(Palette.ink)
                Text("Name, address, phone, property type, star rating, room count if stated, amenities.")
                    .font(.subheadline).foregroundStyle(Palette.inkSecondary)
                Divider().overlay(Palette.hairline)
                Label("What I'll never guess", systemImage: "xmark.circle")
                    .font(.headline).foregroundStyle(Palette.ink)
                Text("Occupancy, ADR, revenue, inventory or booking pace. Those only come from your own data.")
                    .font(.subheadline).foregroundStyle(Palette.inkSecondary)
            }
            .card()
        }
        .onAppear { if url.isEmpty { url = app.profile?.website ?? "" } }
    }

    private func extract() async {
        guard !isWorking, url.trimmed.count >= 4 else { return }
        isWorking = true
        errorText = nil
        defer { isWorking = false }
        do {
            let result: WebsiteExtraction = try await app.api.post(app.path("/website/extract"), json: ["url": .string(url.trimmed)])
            app.extraction = result
            _ = try? await app.updateProfile(["website": .string(result.sourceUrl)])
            app.goTo(.confirm)
        } catch {
            errorText = "\(error.userMessage) You can try another address or skip this step."
        }
    }
}
