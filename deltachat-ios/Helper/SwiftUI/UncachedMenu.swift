import SwiftUI

/// Similar to UIKit's UIDeferredMenuElement.uncached this reloads the menu before it is shown
struct UncachedMenu<Content: View, Label: View>: View {
    var content: () -> Content
    var label: () -> Label
    @State private var menuId = UUID()

    var body: some View {
        Menu(content: { content().id(menuId) }, label: label)
            .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged(reloadMenu))
    }

    func reloadMenu(_: DragGesture.Value) {
        menuId = UUID()
    }
}
