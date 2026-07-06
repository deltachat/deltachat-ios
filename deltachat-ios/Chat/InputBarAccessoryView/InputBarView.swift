import DcCore
import SDWebImageSwiftUI
import SwiftUI

var isLiquidGlassEnabled: Bool = if #available(iOS 26.0, *) { true } else { false }

// TODO: For animations and transitions we need to either rethink the intrinsicContentSize or embed this inside a SwiftUI view (aka rewrite chatviewcontroller to use SwiftUI)
struct InputBarView: View {
    @StateObject var draft: DraftModel
    @FocusState private var textEditorFocus: Bool
    weak var chatViewController: ChatViewController?
    var updateIntrinsicContentSize: () -> Void

    var buttonSize: CGFloat {
        isLiquidGlassEnabled ? 42 : 36
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let msg = draft.sendEditRequestForMsg ?? draft.quoteMessage {
                HStack {
                    QuoteViewSwiftUI(
                        msg: msg,
                        isEditing: draft.sendEditRequestForMsg != nil,
                        dcContext: draft.dcContext
                    ).padding(.horizontal, 10)
                    Button(String.localized("cancel"), systemImage: "xmark") {
                        if draft.sendEditRequestForMsg != nil {
                            draft.clear()
                        } else {
                            draft.setQuote(quotedMsg: nil)
                        }
                    }.layoutPriority(-1).labelStyle(.iconOnly)
                }.modifier { glassEffect(view: $0, interactive: false) }
            }
            if draft.attachment != nil {
                HStack {
                    attachmentPreview
                    Spacer()
                    Button(String.localized("cancel"), systemImage: "xmark") {
                        draft.clearAttachment()
                    }.layoutPriority(-1).labelStyle(.iconOnly)
                }
                .onTapGesture {
                    chatViewController?.onAttachmentTapped()
                }
                .modifier { glassEffect(view: $0, interactive: false) }
            }
            HStack(alignment: .bottom, spacing: 4) {
                UncachedMenu(content: { clipperMenu }, label: {
                    Image("ic_attach_file_36pt", label: Text(String.localized("menu_add_attachment")))
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .padding(2)
                }).frame(height: buttonSize)
                InputBarTextView(
                    text: $draft.text,
                    imagePasteDelegate: chatViewController,
                    textContainerInset: UIEdgeInsets(top: 4, left: 12, bottom: 4, right: 12),
                    maxHeight: 150
                )
                    .focused($textEditorFocus)
                    .overlay(alignment: .leading) {
                        if draft.text.isEmpty && !textEditorFocus {
                            Text(String.localized("chat_input_placeholder"))
                                .foregroundColor(Color(uiColor: DcColors.placeholderColor))
                                .accessibilityHidden(true)
                                .padding(.horizontal, 12)
                        }
                    }
                    .modifier { glassEffect(view: $0, padding: 0, minHeight: buttonSize, interactive: true) }
                    .onTapGesture {
                        textEditorFocus = true
                    }
                    .accessibilityLabel(String.localized("write_message_desktop"))
                Button(action: {
                    draft.send()
                }, label: {
                    Image("paper_plane", label: Text(String.localized("menu_send")))
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .padding(2)
                })
                .frame(height: buttonSize)
                .disabled(!draft.canSend())
            }
        }
        .padding(10)
        .onChange(of: draft.text, perform: _updateIntrinsicContentSize)
        .onChange(of: draft.quoteMessage?.id, perform: _updateIntrinsicContentSize)
        .onChange(of: draft.attachment, perform: _updateIntrinsicContentSize)
        .onChange(of: draft.isFieldFocused) {
            textEditorFocus = $0
        }
        .onChange(of: textEditorFocus) {
            if draft.isFieldFocused != $0 {
                draft.isFieldFocused = $0
            }
        }
        .onAppear {
            textEditorFocus = draft.isFieldFocused
        }
        .modifier { view in
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: 8) {
                    view.buttonBorderShape(.circle)
                        .buttonStyle(.glass)
                }
            } else {
                view.background(Material.bar, ignoresSafeAreaEdges: .bottom)
            }
        }
    }

    @ViewBuilder var attachmentPreview: some View {
        switch draft.viewType {
        case DC_MSG_IMAGE, DC_MSG_GIF:
            WebImage(url: draft.draftMsg?.fileURL)
                .placeholder { ProgressView().padding() }
                .resizable()
                .scaledToFit()
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: buttonSize / 3, style: .continuous))
        case DC_MSG_VIDEO:
            let thumbnail = DcUtils.generateThumbnailFromVideo(url: draft.draftMsg?.fileURL)
            let fallback = UIImage(named: "ic_attach_file_36pt")?.maskWithColor(color: DcColors.grayTextColor)
            Image(uiImage: thumbnail ?? fallback ?? UIImage())
                .resizable()
                .scaledToFit()
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: buttonSize / 3, style: .continuous))
        case DC_MSG_FILE, DC_MSG_WEBXDC:
            if let msg = draft.draftMsg {
                FileViewRepresentable(message: msg, webxdcSummary: String.localized("webxdc_draft_hint"))
                    .frame(minHeight: 50, maxHeight: 75)
            }
        case DC_MSG_VCARD:
            if let msg = draft.draftMsg {
                ContactCardViewRepresentable(message: msg, dcContext: draft.dcContext)
                    .frame(height: 50)
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder var clipperMenu: some View {
        Button(String.localized("camera"), systemImage: "camera") {
            chatViewController?.showCameraViewController()
        }
        Button(String.localized("gallery"), systemImage: "photo.on.rectangle") {
            chatViewController?.showPhotoVideoLibrary()
        }
        Divider()
        Button(String.localized("file"), systemImage: "doc") {
            chatViewController?.showFilesLibrary()
        }
        if chatViewController?.dcChat.isOutBroadcast == false {
            Button(String.localized("webxdc_app"), systemImage: "square.grid.2x2") {
                chatViewController?.showAppPicker()
            }
        }
        Button(String.localized("voice_message"), systemImage: "mic") {
            chatViewController?.showVoiceMessageRecorder()
        }
        if UserDefaults.standard.bool(forKey: "location_streaming") {
            let isLocationStreaming = chatViewController?.isLocationStreaming ?? false
            Button(
                String.localized(isLocationStreaming ? "stop_sharing_location" : "location"),
                systemImage: isLocationStreaming ? "location.slash" : "location"
            ) {
                chatViewController?.locationStreamingButtonPressed()
            }
        }
        Button(String.localized("contact"), systemImage: "person.crop.circle") {
            chatViewController?.showContactList()
        }
    }

    @ViewBuilder func glassEffect<V: View>(view: V, padding: CGFloat = 8, minHeight: CGFloat? = nil, interactive: Bool) -> some View {
        if #available(iOS 26.0, *) {
            view.padding(padding)
                .frame(minHeight: minHeight, alignment: .center)
                .glassEffect(.regular.interactive(interactive), in: .rect(cornerRadius: buttonSize / 2, style: .continuous))
        } else {
            view
        }
    }

    private func _updateIntrinsicContentSize(_: Any) {
        if Thread.isMainThread {
            updateIntrinsicContentSize()
            // Queue another update for after layout settles
            DispatchQueue.main.async(execute: updateIntrinsicContentSize)
        } else {
            DispatchQueue.main.async(execute: updateIntrinsicContentSize)
        }
    }
}
