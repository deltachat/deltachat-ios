import AppIntents
import DcCore
import LinkPresentation
import SwiftUI

// TODO: Dismiss button?
// TODO: Make the iOS 16 steps more clear? Not sure how.

@available(iOS 16, *)
struct AddWebxdcToHomescreenTipView: View {
    var accountId: Int
    var chat: DcChat
    var msg: DcMsg

    @State private var shareSheetImage: UIImage?

    var body: some View {
        Form {
            if #available(iOS 17, *) {
                iOS17
            } else if #available(iOS 16, *) {
                iOS16
            }
        }
    }

    var iOS16: some View {
        Section(header: Text("Add to homescreen")) {
            step(1) {
                Text("Save icon to Photos")
                Spacer()
                Button {
                    shareSheetImage = msg.getWebxdcPreviewImage()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }.imageShareSheet(image: $shareSheetImage)
            }
            step(2) {
                Text("Open the Delta Chat section in Shortcuts:")
                Spacer()
                ShortcutsLink()
            }
            step(3) {
                Text("Find \"Open a webxdc app in Delta Chat\"")
            }
            step(4) {
                Image(systemName: "ellipsis.circle.fill")
                    .resizable()
                    .frame(width: 25, height: 25)
                Text("Use in New Shortcut")
            }
            step(5) {
                Image(systemName: "chevron.right.circle")
                    .resizable()
                    .frame(width: 25, height: 25)
                    .foregroundStyle(Color.accentColor)
                Text("Choose the webxdc app you want to open")
            }
            step(6) {
                Image(systemName: "chevron.down.circle.fill")
                    .resizable()
                    .frame(width: 25, height: 25)
                    .symbolRenderingMode(.hierarchical)
                Text("Add to homescreen")
            }
            step(7) {
                Text("Set Home Screen Name to the name of the webxdc app")
            }
            step(8) {
                Text("Add the Icon from step 1")
            }
        }
    }

    @available(iOS 17, *)
    var iOS17: some View {
        Section(header: Text("Add to homescreen")) {
            step(1) {
                Text("Open the Delta Chat section in Shortcuts:")
                Spacer()
                ShortcutsLink()
            }
            step(2) {
                Text("Find \"Open <webxdc app you want to add to homescreen> in Delta Chat\"")
            }
            step(3) {
                Image(systemName: "ellipsis.circle.fill")
                    .resizable()
                    .frame(width: 25, height: 25)
                Text("Add to homescreen")
            }
        }.onAppear {
            WebXDCAppEntity.defaultQuery.onlySuggestWebxdcApp = WebXDCAppEntity(accountId: accountId, chat: chat, msg: msg)
        }.onDisappear {
            WebXDCAppEntity.defaultQuery.onlySuggestWebxdcApp = nil
        }
    }

    func step(_ i: Int, @ViewBuilder view: () -> some View) -> some View {
        HStack {
            Text("\(i)")
                .frame(width: 25, height: 25, alignment: .center)
                .background(Color.gray.opacity(0.3))
                .clipShape(Circle())
            view()
        }
    }
}

///  A view for sharing an image. The user can add the image to their cameraroll, share it via iMessage, etc.
@available(iOS 13.0, *)
private struct ImageShareSheet: UIViewControllerRepresentable {
    /// The images to share
    let image: UIImage

    func makeUIViewController(context: Context) -> some UIViewController {
        let tempImageURL = FileManager.default.temporaryDirectory.appendingPathComponent("webxdc-app-icon.png")
        try? FileManager.default.removeItem(at: tempImageURL)
        try? image.pngData()?.write(to: tempImageURL)

        let activityViewController = UIActivityViewController(activityItems: [tempImageURL], applicationActivities: nil)
        activityViewController.excludedActivityTypes = [
            .print,
            .openInIBooks,
            .copyToPasteboard,
            .addToReadingList,
            .assignToContact,
            .copyToPasteboard,
            .mail,
            .markupAsPDF,
            .postToFacebook,
            .postToWeibo,
            .postToVimeo,
            .postToFlickr,
            .postToTwitter,
            .postToTencentWeibo,
            .message,
        ]

        return activityViewController
    }

    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {}
}

@available(iOS 13.0, *)
extension View {
    func imageShareSheet(
        image: Binding<UIImage?>
    ) -> some View {
        sheet(item: image, content: { ImageShareSheet(image: $0) })
    }
}

extension UIImage: @retroactive Identifiable {
    public var id: Data { self.pngData() ?? Data() }
}
