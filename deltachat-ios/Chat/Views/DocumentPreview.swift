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

    override func setupSubviews() {
        super.setupSubviews()
        mainContentView.addSubview(fileView)
        addConstraints([
            fileView.constraintAlignTopTo(mainContentView),
            fileView.constraintAlignLeadingTo(mainContentView, paddingLeading: 8),
            fileView.constraintAlignBottomTo(mainContentView),
            fileView.constraintAlignTrailingTo(mainContentView),
            mainContentView.constraintHeightTo(75, priority: .required)
        ])
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(fileViewTapped))
        fileView.addGestureRecognizer(gestureRecognizer)
    }
    
    override public func cancel() {
        fileView.prepareForReuse()
        delegate?.onCancelAttachment()
    }

    override public func configure(draft: DraftModel) {
        if !draft.isEditing,
           draft.viewType == DC_MSG_FILE,
           let path = draft.attachment {
            let tmpMsg = DcMsg(viewType: DC_MSG_FILE)
            tmpMsg.setFile(filepath: path)
            tmpMsg.text = draft.text
            fileView.configure(message: tmpMsg)
            self.delegate?.onAttachmentAdded()
            isHidden = false
        } else {
            isHidden = true
        }
    }

    @objc func fileViewTapped() {
        delegate?.onAttachmentTapped()
    }
}
