import SwiftUI

extension View {
    public func calculated(size: Binding<CGSize>) -> some View {
        self.modifier(CalculatedSizePreferenceModifier(size: size))
    }
}

private struct CalculatedSizePreferenceModifier: ViewModifier {
    @Binding var size: CGSize

    func body(content: Content) -> some View {
        content
            .background(GeometryReader { geometry in
                Color.clear.preference(key: CalculatedSizePreferenceKey.self, value: geometry.size)
            })
            .onPreferenceChange(CalculatedSizePreferenceKey.self) {
                size = $0
            }
    }
}

private struct CalculatedSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {}
}
