import UIKit
import DcCore

public class ContactCardPreview: DraftPreview {

    weak var delegate: DraftPreviewDelegate?

    lazy var contactCardView: ContactCardView = {
        let view = ContactCardView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = true
        return view
    }()

    override func setupSubviews() {
        super.setupSubviews()
        mainContentView.addSubview(contactCardView)

        addConstraints([
            contactCardView.constraintAlignTopTo(mainContentView),
            contactCardView.constraintAlignLeadingTo(mainContentView, paddingLeading: 8),
            contactCardView.constraintAlignBottomTo(mainContentView),
            contactCardView.constraintAlignTrailingTo(mainContentView),
            mainContentView.constraintHeightTo(75, priority: .required)
        ])

        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(contactCardViewTapped))
        contactCardView.addGestureRecognizer(gestureRecognizer)
    }
    
    override public func cancel() {
        contactCardView.prepareForReuse()
        delegate?.onCancelAttachment()
        accessibilityLabel = nil
    }

    override public func configure(draft: DraftModel) {
        if !draft.isEditing,
           let viewType = draft.viewType,
           viewType == DC_MSG_VCARD,
           let path = draft.attachment {
            var tmpMsg: DcMsg
            if let draftMsg = draft.draftMsg {
                tmpMsg = draftMsg
            } else {
                tmpMsg = draft.dcContext.newMessage(viewType: viewType)
                tmpMsg.setFile(filepath: path)
                tmpMsg.text = draft.text
            }

            contactCardView.configure(message: tmpMsg, dcContext: draft.dcContext)

            delegate?.onAttachmentAdded()
            accessibilityLabel = "\(String.localized("attachment")), \(contactCardView.configureAccessibilityLabel())"
            isHidden = false
        } else {
            isHidden = true
        }
    }

    @objc func contactCardViewTapped() {
    }
}
