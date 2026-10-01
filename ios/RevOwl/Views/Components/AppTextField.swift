import SwiftUI
import UIKit

/// Text input whose whole box is a tap target: tapping anywhere inside focuses the field
/// and brings up the keyboard, not just the thin line of text in the middle.
struct AppTextField: View {
    let placeholder: String
    @Binding var text: String
    let id: String
    var icon: String?
    var axis: Axis = .horizontal
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType?
    var capitalization: TextInputAutocapitalization = .sentences
    var autocorrect: Bool = true
    var submitLabel: SubmitLabel = .done
    var font: Font = .body
    var alignment: TextAlignment = .leading
    var isBusy: Bool = false
    var accessibilityLabel: String?
    var onSubmit: (() -> Void)?

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            if let icon {
                Image(systemName: icon)
                    .foregroundStyle(isFocused ? Palette.teal : Palette.inkTertiary)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            TextField(placeholder, text: $text, axis: axis)
                .font(font)
                .multilineTextAlignment(alignment)
                .keyboardType(keyboard)
                .textContentType(contentType)
                .textInputAutocapitalization(capitalization)
                .autocorrectionDisabled(!autocorrect)
                .submitLabel(submitLabel)
                .lineLimit(axis == .vertical ? 1...5 : 1...1)
                .focused($isFocused)
                .onSubmit { onSubmit?() }
                .accessibilityLabel(accessibilityLabel ?? placeholder)
                .accessibilityIdentifier(id)
            if isBusy {
                ProgressView().allowsHitTesting(false)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: 48)
        .background {
            RoundedRectangle(cornerRadius: Metrics.smallRadius)
                .fill(Palette.surfaceRaised)
                .contentShape(.rect)
                .onTapGesture { isFocused = true }
        }
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.smallRadius)
                .strokeBorder(isFocused ? Palette.teal : Color.clear, lineWidth: 1.5)
                .allowsHitTesting(false)
        }
        .animation(.easeOut(duration: 0.15), value: isFocused)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("\(id).box")
    }
}

extension UIApplication {
    /// Resigns whichever field currently has the keyboard.
    static func dismissKeyboard() {
        shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

private struct KeyboardDoneToolbar: ViewModifier {
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { UIApplication.dismissKeyboard() }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("keyboard.done")
            }
        }
    }
}

extension View {
    /// Adds a "Done" button above the keyboard. Needed for number and phone pads, which have no return key.
    /// Apply once per screen or sheet.
    func keyboardDoneButton() -> some View {
        modifier(KeyboardDoneToolbar())
    }
}
