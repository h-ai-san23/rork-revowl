import AuthenticationServices
import SwiftUI

struct SignInStep: View {
    @Environment(AppModel.self) private var app
    @Environment(\.colorScheme) private var colorScheme
    @State private var rawNonce = ""
    @State private var isWorking = false
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                OrevBubble(
                    state: isWorking ? .thinking : (errorText == nil ? .listening : .errorRecovery),
                    title: "Let's set up your account",
                    message: "Sign in with Apple keeps your property private and synced across your devices. Teammates can join later with an invite."
                )

                SignInWithAppleButton(.continue) { request in
                    let nonce = AuthNonce.random()
                    rawNonce = nonce
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = AuthNonce.sha256(nonce)
                } onCompletion: { result in
                    handle(result)
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 54)
                .clipShape(.capsule)
                .disabled(isWorking)

                if app.capabilities?.deviceSignIn ?? true {
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            Task { await deviceSignIn() }
                        } label: {
                            if isWorking { ProgressView() } else { Text("Continue on this device only") }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(isWorking)
                        .accessibilityIdentifier("signin.device")
                        Text("Useful for testing or on simulators. The account is tied to this device and can't be recovered if the app is deleted.")
                            .font(.footnote)
                            .foregroundStyle(Palette.inkTertiary)
                    }
                }

                if let errorText {
                    InlineMessage(kind: .error, text: errorText)
                }

                Label("We never sell your data. Your property's numbers are only visible to your team.", systemImage: "lock.shield")
                    .font(.footnote)
                    .foregroundStyle(Palette.inkSecondary)
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.top, 24)
        }
    }

    private func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let data = credential.identityToken,
                  let token = String(data: data, encoding: .utf8) else {
                errorText = "Apple didn't return a sign-in token. Please try again."
                return
            }
            let name = credential.fullName.map { PersonNameComponentsFormatter.localizedString(from: $0, style: .default) }?.nilIfEmpty
            let email = credential.email
            let nonce = rawNonce
            Task {
                isWorking = true
                errorText = nil
                do {
                    try await app.signInWithApple(identityToken: token, rawNonce: nonce, fullName: name, email: email)
                } catch {
                    errorText = error.userMessage
                }
                isWorking = false
            }
        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled { return }
            errorText = "Sign in with Apple isn't available right now. Check that you're signed in to an Apple Account in Settings."
        }
    }

    private func deviceSignIn() async {
        isWorking = true
        errorText = nil
        do {
            try await app.signInOnDevice()
        } catch {
            errorText = error.userMessage
        }
        isWorking = false
    }
}
