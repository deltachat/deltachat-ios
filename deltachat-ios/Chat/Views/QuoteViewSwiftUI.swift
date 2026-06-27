import DcCore
import SwiftUI

struct QuoteViewSwiftUI: View {
    var msg: DcMsg
    var isEditing: Bool
    var dcContext: DcContext

    @State private var size: CGSize = .zero

    var body: some View {
        let contact = isEditing ? nil : dcContext.getContact(id: msg.fromContactId)
        let color = Color(uiColor: contact?.color ?? DcColors.unknownSender)
        HStack {
            VStack(alignment: .leading) {
                if isEditing {
                    Text(String.localized("edit_message"))
                        .foregroundColor(color)
                        .font(.preferredFont(for: .caption1, weight: .semibold))
                } else if msg.isForwarded {
                    Text(String.localized("forwarded_message"))
                        .foregroundColor(color)
                        .font(.preferredFont(for: .caption1, weight: .semibold))
                } else if let contact {
                    Text(msg.getSenderName(contact, markOverride: true))
                        .foregroundColor(color)
                        .font(.preferredFont(for: .caption1, weight: .semibold))
                }
                Text(msg.text ?? "")
                    .font(.preferredFont(for: .subheadline, weight: .regular))
                    .lineLimit(3)
            }
            .padding(.leading)
            .calculated(size: $size)
            Spacer()
            if let quoteImage = msg.type == DC_MSG_WEBXDC ? msg.getWebxdcPreviewImage() : msg.image {
                Image(uiImage: quoteImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: size.height)
            }
        }
        .overlay(alignment: .leading) {
            Capsule(style: .circular)
                .fill(color)
                .frame(width: 3)
        }
    }
}
