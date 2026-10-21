import DcCore
import SwiftUI

struct PinBarView: View {
    let context: DcContext
    let chat: DcChat
    let scrollToMsg: (DcMsg) -> Void
    let startWebxdc: (DcMsg) -> Void
    @State private var pins: [Int] = [] {
        willSet { selected = max(0, min(selected, newValue.count-1)) }
    }
    @State private var selected: Int = 0
    /// Increased when a pinned message is edited to reload the view
    @State private var edits: Int = 0
    @State private var size: CGSize = .zero

    @ScaledMetric(relativeTo: .body) private var imageSize = 26

    var body: some View {
        VStack {
            if !pins.isEmpty {
                view
            }
        }
        .onAppear {
            pins = chat.pinnedMessageIds
        }
        .onReceive(NotificationCenter.default.publisher(for: Event.messagesChanged).receive(on: RunLoop.main)) { event in
            if let msg = (event.userInfo?["message_id"] as? Int).map(context.getMessage),
               msg.isPinned && msg.isEdited {
                edits += 1
            }
            if event.userInfo?["chat_id"] as? Int == chat.id {
                withAnimation {
                    pins = chat.pinnedMessageIds
                }
            }
        }
    }

    @ViewBuilder var view: some View {
        let msg = context.getMessage(id: pins[selected])
        HStack {
            if #available(iOS 16, *), pins.count > 1 {
                PinPageControl(currentPage: selected, numberOfPages: pins.count)
                    .frame(maxHeight: imageSize + 16)
                    .padding(.vertical, -8)
                    .padding(.leading, 8)
            }
            HStack {
                if let image = msg.image ?? msg.getWebxdcPreviewImage() {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                        .frame(width: imageSize, height: imageSize)
                }
                Text(msg.summary(addForwarded: false, addTypeEmoji: false, chars: 100) ?? "...")
                    .lineLimit(1)
                    .opacity(0.9)
                    .padding(.vertical, 10)
            }
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
            ))
            .padding(.leading, pins.count > 1 ? 0 : 16)
            .id("\(pins[selected])-\(edits)")
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
                    .font(.system(size: 13))
                    .foregroundColor(Color(DcColors.middleGray))
                    .padding(.trailing, 12)
            }
        }
        .clipped()
        .contentShape(.containerRelative)
        .modifier { view in
            if #available(iOS 26.0, *) {
                view.glassEffect(.regular.interactive())
                    .contextMenu { contextMenu(for: msg) }
                    .padding(.horizontal)
            } else {
                view.background(Material.bar, ignoresSafeAreaEdges: .bottom)
                    .contextMenu { contextMenu(for: msg) }
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
    }

    @ContentBuilder func contextMenu(for msg: DcMsg) -> some View {
        Button(action: {
            msg.isPinned = false
        }, label: {
            Label(String.localized("unpin"), systemImage: "pin.slash")
        })
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
        control.pageIndicatorTintColor = .lightGray
        control.currentPageIndicatorTintColor = .themeColor(light: .darkText, dark: .white)
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
