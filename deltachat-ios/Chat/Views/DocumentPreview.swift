import UIKit
import DcCore

public class DocumentPreview: DraftPreview {

    weak var delegate: DraftPreviewDelegate?

    lazy var fileView: FileView = {
        let view = FileView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.allowLayoutChange = false
        view.fileTitle.numberOfLines = 2
        view.isUserInteractionEnabled = true
        return view
    }()

    lazy var contactCardView: ContactCardView = {
        let view = ContactCardView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = true
        return view
    }()

    override func setupSubviews() {
        super.setupSubviews()
        mainContentView.addSubview(fileView)
        mainContentView.addSubview(contactCardView)

        addConstraints([
            fileView.constraintAlignTopTo(mainContentView),
            fileView.constraintAlignLeadingTo(mainContentView, paddingLeading: 8),
            fileView.constraintAlignBottomTo(mainContentView),
            fileView.constraintAlignTrailingTo(mainContentView),
            mainContentView.constraintHeightTo(75, priority: .required)
        ])

        addConstraints([
            contactCardView.constraintAlignTopTo(mainContentView),
            contactCardView.constraintAlignLeadingTo(mainContentView, paddingLeading: 8),
            contactCardView.constraintAlignBottomTo(mainContentView),
            contactCardView.constraintAlignTrailingTo(mainContentView)
        ])

        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(fileViewTapped))
        fileView.addGestureRecognizer(gestureRecognizer)
    }
    
    override public func cancel() {
        fileView.prepareForReuse()
        delegate?.onCancelAttachment()
        accessibilityLabel = nil
    }

    override public func configure(draft: DraftModel) {
        if !draft.isEditing,
           let viewType = draft.viewType,
           [DC_MSG_WEBXDC, DC_MSG_FILE, DC_MSG_VCARD].contains(viewType),
           let path = draft.attachment {
            var tmpMsg: DcMsg
            if let draftMsg = draft.draftMsg {
                tmpMsg = draftMsg
            } else {
                tmpMsg = draft.dcContext.newMessage(viewType: viewType)
                tmpMsg.setFile(filepath: path)
                tmpMsg.text = draft.text
            }

            if viewType == DC_MSG_VCARD {
                contactCardView.isHidden = false
                fileView.isHidden = true
                contactCardView.configure(message: tmpMsg, dcContext: draft.dcContext)
            } else {
                contactCardView.isHidden = true
                fileView.isHidden = false
                fileView.configure(message: tmpMsg)
                fileView.fileTitle.numberOfLines = 2
            }

            delegate?.onAttachmentAdded()
            accessibilityLabel = "\(String.localized("attachment")), \(fileView.configureAccessibilityLabel())"
            isHidden = false
        } else {
            isHidden = true
        }
    }

    @objc func fileViewTapped() {
        delegate?.onAttachmentTapped()
    }
}
