// Probe branch only: a plain SwiftUI window shaped like System Settings, to compare with the kit's.
import SwiftUI

@main
struct Replica: App {
    @State private var selection: String? = "General"
    private let pages = ["General", "Appearance", "Advanced"]

    var body: some Scene {
        Window("General", id: "replica") {
            NavigationSplitView {
                List(pages, id: \.self, selection: $selection) { page in
                    Label(page, systemImage: "gearshape")
                }
                .navigationSplitViewColumnWidth(215)
            } detail: {
                Form {
                    ForEach(1...5, id: \.self) { row in
                        Toggle("Setting \(row)", isOn: .constant(row.isMultiple(of: 2)))
                    }
                }
                .formStyle(.grouped)
                .navigationTitle(selection ?? "")
                .toolbar {
                    ToolbarItemGroup(placement: .navigation) {
                        Button {} label: { Image(systemName: "chevron.backward") }
                        Button {} label: { Image(systemName: "chevron.forward") }
                    }
                }
            }
            .toolbar(removing: .sidebarToggle)
            .frame(width: 715, height: 600)
        }
        .windowResizability(.contentSize)
    }
}
