import SwiftUI

public extension View {
    /// Modify a view with a `ViewBuilder` closure.
    ///
    /// This represents a streamlining of the
    /// [`modifier`](https://developer.apple.com/documentation/swiftui/view/modifier(_:))
    /// \+ [`ViewModifier`](https://developer.apple.com/documentation/swiftui/viewmodifier)
    /// pattern.
    /// - Note: Do not use this with variables that change at runtime
    func modifier<ModifiedContent: View>(
        @ViewBuilder _ body: (_ content: Self) -> ModifiedContent
    ) -> ModifiedContent {
        body(self)
    }
}
