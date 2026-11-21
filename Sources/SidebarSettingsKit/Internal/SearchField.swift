import AppKit
import SwiftUI

/// AppKit's search field, for a field above the list rather than `.searchable`'s. It takes
/// ⌘F from anywhere in its window, as System Settings' field does; Esc clears it, and ↓ calls
/// `moveDown`.
struct SearchField: NSViewRepresentable {
    @Binding var text: String
    let prompt: String
    let moveDown: @MainActor () -> Void

    func makeNSView(context: Context) -> NSSearchField {
        let field = FindShortcutSearchField()
        field.sendsSearchStringImmediately = true
        field.placeholderString = prompt
        field.target = context.coordinator
        field.action = #selector(Coordinator.searchChanged(_:))
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        if field.stringValue != text { field.stringValue = text }
        field.placeholderString = prompt
        context.coordinator.moveDown = moveDown
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, moveDown: moveDown)
    }

    @MainActor
    final class Coordinator: NSObject, NSSearchFieldDelegate {
        private let text: Binding<String>
        var moveDown: @MainActor () -> Void

        init(text: Binding<String>, moveDown: @escaping @MainActor () -> Void) {
            self.text = text
            self.moveDown = moveDown
        }

        @objc func searchChanged(_ field: NSSearchField) {
            text.wrappedValue = field.stringValue
        }

        // The field editor sends ↓ as `moveDown:`; on a one-line field it would only move the
        // insertion point to the end.
        func control(
            _ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector
        ) -> Bool {
            guard commandSelector == #selector(NSResponder.moveDown(_:)) else { return false }
            moveDown()
            return true
        }
    }
}

private final class FindShortcutSearchField: NSSearchField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
            event.charactersIgnoringModifiers == "f"
        else { return super.performKeyEquivalent(with: event) }
        return window?.makeFirstResponder(self) ?? false
    }
}
