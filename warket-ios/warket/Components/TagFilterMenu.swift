import SwiftUI

/// Toolbar filter: pick one tag or All Tags. The button turns prominent while a tag is active,
/// the one signal that the list is filtered.
struct TagFilterMenu: View {
    let tags: [String]
    @Binding var selection: String?

    var body: some View {
        if selection == nil {
            menu
        } else {
            menu.buttonStyle(.glassProminent)
        }
    }

    private var menu: some View {
        Menu {
            Picker("Filter by Tag", selection: $selection) {
                Text("All Tags").tag(String?.none)
                ForEach(tags, id: \.self) { tag in
                    Text("#\(tag)").tag(String?.some(tag))
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label("Filter", systemImage: "line.3.horizontal.decrease")
        }
    }
}
