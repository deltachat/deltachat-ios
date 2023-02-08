import Foundation
import DcCore
import UIKit

class TextMessageCell: BaseMessageCell {

    override func setupSubviews() {
        super.setupSubviews()
        mainContentView.addArrangedSubview(messageLabel)
        messageLabel.paddingLeading = 12
        messageLabel.paddingTrailing = 12
    }

    override func update(dcContext: DcContext, msg: DcMsg, messageStyle: UIRectCorner, showAvatar: Bool, showName: Bool, searchText: String?, highlight: Bool) {
        messageLabel.text = msg.text
        
        var fontSize = UIFont.preferredFont(for: .body, weight: .regular).pointSize
        // calculate jumbomoji size
        if msg.text != nil {
            let text = msg.text! // simon: not sure how we can get rid of this `!`
            let charCount = text.count
            // simon: as far as I understood, this iterates over the whole string to find out how many unicode clusters there are,
            // so we might wanna cache it here instead of calculating it twice
            if charCount <= 8 && text.containsOnlyEmoji {
                if charCount <= 2 {
                    fontSize *= 3.0
                } else if charCount <= 4 {
                    fontSize *= 2.5
                } else if charCount <= 6 {
                    fontSize *= 1.75
                } else {
                    fontSize *= 1.35
                }
            }
        }
        messageLabel.font = messageLabel.font.withSize(fontSize)
        // messageLabel.traitCollection

        super.update(dcContext: dcContext,
                     msg: msg,
                     messageStyle: messageStyle,
                     showAvatar: showAvatar,
                     showName: showName,
                     searchText: searchText,
                     highlight: highlight)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
    }
    
}



// required extentions to Character and String
// thanks to https://stackoverflow.com/a/39425959

extension Character {
    var isSimpleEmoji: Bool {
        guard let firstScalar = unicodeScalars.first else {
            return false
        }
        return firstScalar.properties.isEmoji && firstScalar.value > 0x238C
    }
    var isCombinedIntoEmoji: Bool {
        unicodeScalars.count > 1 && unicodeScalars.first?.properties.isEmoji ?? false
    }
    var isEmoji: Bool { isSimpleEmoji || isCombinedIntoEmoji }
}

extension String {
    var containsOnlyEmoji: Bool {
        return !isEmpty && !contains { !$0.isEmoji }
    }
}
