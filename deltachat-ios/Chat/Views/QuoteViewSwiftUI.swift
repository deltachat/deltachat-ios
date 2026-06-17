import DcCore
import SwiftUI

struct QuoteViewSwiftUI: View {
    var quoteText: String?
    var quoteMessage: DcMsg?
    var dcContext: DcContext

    @State private var size: CGSize = .zero

    var body: some View {
        if let quoteText {
            let quoteContact = quoteMessage.flatMap { dcContext.getContact(id: $0.fromContactId) }
            let color = Color(uiColor: quoteContact?.color ?? DcColors.unknownSender)
            HStack {
                VStack(alignment: .leading) {
                    if quoteMessage?.isForwarded == true {
                        Text(String.localized("forwarded_message"))
                            .foregroundColor(color)
                            .font(.init(UIFont.preferredFont(for: .caption1, weight: .semibold)))
                    } else if let quoteMessage, let quoteContact {
                        Text(quoteMessage.getSenderName(quoteContact, markOverride: true))
                            .foregroundColor(color)
                            .font(.preferredFont(for: .caption1, weight: .semibold))
                    }
                    Text(quoteText)
                        .font(.preferredFont(for: .subheadline, weight: .regular))
                        .lineLimit(3)
                }
                .padding(.leading)
                .calculated(size: $size)
                Spacer()
                let isWebxdc = quoteMessage?.type == DC_MSG_WEBXDC
                if let quoteImage = isWebxdc ? quoteMessage?.getWebxdcPreviewImage() : quoteMessage?.image {
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
}
