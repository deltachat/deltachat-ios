import UIKit
import SDWebImage
import DcCore

class MediaPreview: DraftPreview {
    var imageWidthConstraint: NSLayoutConstraint?
    weak var delegate: DraftPreviewDelegate?

    public lazy var contentImageView: SDAnimatedImageView = {
        let imageView = SDAnimatedImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 4
        imageView.isUserInteractionEnabled = true
        return imageView
    }()

    override func setupSubviews() {
        super.setupSubviews()
        mainContentView.addSubview(contentImageView)
        addConstraints([
            contentImageView.constraintAlignTopTo(mainContentView),
            contentImageView.constraintAlignLeadingTo(mainContentView, paddingLeading: 14),
            contentImageView.constraintAlignTrailingMaxTo(mainContentView, paddingTrailing: 14),
            contentImageView.constraintAlignBottomTo(mainContentView),
            contentImageView.constraintHeightTo(90)
        ])
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(imageTapped))
        contentImageView.addGestureRecognizer(gestureRecognizer)
    }

    override func configure(draft: DraftModel) {
        if draft.isEditing {
            self.isHidden = true
            return
        }
        
        if draft.viewType == DC_MSG_GIF || draft.viewType == DC_MSG_IMAGE, let path = draft.attachment {
            contentImageView.sd_setImage(with: URL(fileURLWithPath: path, isDirectory: false), completed: { image, error, _, _ in
                if let error = error {
                    logger.error("could not load draft image: \(error)")
                    self.cancel()
                } else if let image = image {
                    self.setAspectRatio(image: image)
                    self.delegate?.onAttachmentAdded()
                    self.accessibilityLabel =
                        "\(String.localized("attachment")), \(draft.viewType == DC_MSG_GIF ? String.localized("gif") : String.localized("image"))"
                }
            })
            isHidden = false
        } else if draft.viewType == DC_MSG_VIDEO, let path = draft.attachment {
            DispatchQueue.global(qos: .userInteractive).async {
                let thumbnailImage = DcUtils.generateThumbnailFromVideo(url: URL(fileURLWithPath: path, isDirectory: false))
                if let thumbnailImage = thumbnailImage {
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        self.contentImageView.image = thumbnailImage
                        self.setAspectRatio(image: thumbnailImage)
                        self.delegate?.onAttachmentAdded()
                    }
                }
            }
            self.isHidden = false
            self.accessibilityLabel = "\(String.localized("attachment")), \(String.localized("video"))"
        } else {
            isHidden = true
        }
    }

    override public func cancel() {
        contentImageView.sd_cancelCurrentImageLoad()
        contentImageView.image = nil
        delegate?.onCancelAttachment()
        accessibilityLabel = nil
    }

    func setAspectRatio(image: UIImage) {
        let height = image.size.height
        let width = image.size.width
        imageWidthConstraint?.isActive = false
        imageWidthConstraint = contentImageView.widthAnchor.constraint(lessThanOrEqualTo: contentImageView.heightAnchor, multiplier: width / height)
        imageWidthConstraint?.isActive = true
    }

    @objc func imageTapped() {
        delegate?.onAttachmentTapped()
    }

    func reload(draft: DraftModel) {
        guard let attachment = draft.attachment else { return }
        let url = URL(fileURLWithPath: attachment, isDirectory: false)
        // there are editing options for DC_MSG_GIF, so that can be ignored
        if draft.viewType == DC_MSG_IMAGE {
            SDImageCache.shared.removeImage(forKey: url.absoluteString, withCompletion: { [weak self] in
                self?.configure(draft: draft)
            })
        } else if draft.viewType == DC_MSG_VIDEO {
            self.configure(draft: draft)
        }
    }
}
