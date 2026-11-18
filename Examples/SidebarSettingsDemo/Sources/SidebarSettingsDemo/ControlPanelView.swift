import SwiftUI

/// The demo's main window: every option of the kit in one place. The settings window keeps
/// the configuration it was built with, so the button at the bottom closes it and builds the
/// next one.
struct ControlPanelView: View {
    let demo: Demo
    @State private var options: DemoOptions

    init(demo: Demo) {
        self.demo = demo
        _options = State(initialValue: demo.options)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Sidebar") {
                    option("Style", $options.style)
                    option("Pages", $options.pages)
                    option("Grouping", $options.grouping)
                }
                Section("Sidebar chrome") {
                    option("Header and footer", $options.chrome)
                    Toggle("Tall footer (80 pt login area)", isOn: $options.tallFooter)
                        .disabled(!options.chrome.showsFooter)
                }
                Section("Window") {
                    option("Size", $options.size)
                    option("Resizing", $options.resizing)
                    Toggle("Autosave position", isOn: $options.autosave)
                    option("Sidebar width", $options.sidebarWidth)
                    option("Toolbar style", $options.toolbarStyle)
                    Toggle("Back and forward buttons", isOn: $options.showsNavigationButtons)
                    option("Title", $options.title)
                }
                Section("Behavior") {
                    option("Toolbar separator", $options.separator)
                    Toggle("Search field", isOn: $options.search)
                    Toggle("Kit scrolls the detail", isOn: $options.detailScrolling)
                    option("Reopening shows", $options.navigationPersistence)
                    Toggle("Custom strings", isOn: $options.customStrings)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack(spacing: 12) {
                Text("The settings window keeps its configuration; this builds the next one.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Button("Open Settings") {
                    demo.apply(options)
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(minWidth: 520, idealWidth: 560, minHeight: 560, idealHeight: 660)
    }

    private func option<Choice: DemoChoice>(
        _ title: String,
        _ selection: Binding<Choice>
    ) -> some View {
        Picker(title, selection: selection) {
            ForEach(Array(Choice.allCases), id: \.self) { choice in
                Text(choice.label)
                    .tag(choice)
            }
        }
    }
}
