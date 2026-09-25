import DcCore
import SwiftUI

struct PinBarView: View {
    let context: DcContext
    let chat: DcChat
    let scrollToMsg: (DcMsg) -> Void
    let startWebxdc: (DcMsg) -> Void
    @State private var pins: [Int] = [] {
        willSet { selected = min(selected, newValue.count) }
    }
    @State private var selected: Int = 0
    @State private var size: CGSize = .zero

    var body: some View {
        VStack {
            if !pins.isEmpty {
                view
            }
        }
        .onAppear {
            pins = chat.pinnedMessageIds
        }
        // TODO: Switch to "pinned messages changed" event here
        .onReceive(NotificationCenter.default.publisher(for: Event.messagesChanged)) { event in
            guard event.userInfo?["chat_id"] as? Int == chat.id else { return }
            withAnimation {
                pins = chat.pinnedMessageIds
            }
        }
    }

    @ViewBuilder var view: some View {
        let msg = context.getMessage(id: pins[selected])
        HStack {
            if #available(iOS 16, *) {
                PinPageControl(currentPage: selected, numberOfPages: pins.count)
                    .frame(maxHeight: size.height)
                    .padding(.leading, 8)
            }
            Text(msg.summary(chars: 100) ?? "...")
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
                .lineLimit(1)
                .padding(.vertical, 10)
                .opacity(0.7)
                .id(selected)
                .bind(size: $size)
            Spacer()
            if msg.type == DC_MSG_WEBXDC {
                Button(String.localized("start_app")) {
                    startWebxdc(msg)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .padding(4)
            } else {
                Image(systemName: "pin.fill")
                    .padding(.trailing, 12)
            }
        }
        .clipped()
        .modifier { view in
            if #available(iOS 26.0, *) {
                view.glassEffect(.regular.interactive())
                    .padding(.horizontal)
            } else {
                view.background(Material.bar, ignoresSafeAreaEdges: .bottom)
                    .overlay(alignment: .bottom, content: Divider.init)
            }
        }
        .padding(.bottom, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onTapGesture {
            scrollToMsg(msg)
            withAnimation {
                selected = (selected + 1) % pins.count
            }
        }
        .contextMenu {
            Button(action: {
                msg.isPinned = false
            }, label: {
                Label("Unpin", systemImage: "pin.slash.fill")
            })
        }
    }
}

@available(iOS 16, *)
public struct PinPageControl: UIViewRepresentable {
    public var currentPage: Int
    public var numberOfPages: Int

    public func makeUIView(context: Context) -> UIPageControl {
        let control = UIPageControl()
        control.numberOfPages = numberOfPages
        control.currentPage = currentPage
        control.isUserInteractionEnabled = false
        control.direction = .bottomToTop
        control.transform = .identity.scaledBy(x: 0.4, y: 0.4)
        control.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return control
    }

    public func updateUIView(_ uiView: UIPageControl, context: Context) {
        uiView.numberOfPages = numberOfPages
        uiView.currentPage = currentPage
    }

    @available(iOS 16.0, macCatalyst 16.0, tvOS 16.0, visionOS 1.0, *)
    public func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIPageControl, context: Context) -> CGSize? {
        let natural = uiView.size(forNumberOfPages: numberOfPages)
        return CGSize(width: natural.width, height: proposal.height ?? natural.height)
    }
}

extension View {
    func bind(size: Binding<CGSize>) -> some View {
        background(GeometryReader { proxy in
            Color.clear.preference(key: SizePreferenceKey.self, value: proxy.size)
        }).onPreferenceChange(SizePreferenceKey.self) {
            size.wrappedValue = $0
        }
    }
}

private struct SizePreferenceKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}
