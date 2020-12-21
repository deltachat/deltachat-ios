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
        if (draft.draftViewType == DC_MSG_GIF || draft.draftViewType == DC_MSG_IMAGE), let path = draft.draftAttachment {
            contentImageView.sd_setImage(with: URL(fileURLWithPath: path, isDirectory: false), completed: { image, error, _, _ in
                if let error = error {
                    logger.error("could not load draft image: \(error)")
                    self.cancel()
                } else if let image = image {
                    self.setAspectRatio(image: image)
                    self.delegate?.onAttachmentAdded()
                }
            })
            isHidden = false
        } else if draft.draftViewType == DC_MSG_VIDEO, let path = draft.draftAttachment {
            if let image = ThumbnailCache.shared.restoreImage(key: path) {
                self.contentImageView.image = image
                self.setAspectRatio(image: image)
            } else {
                DispatchQueue.global(qos: .userInteractive).async {
                    let thumbnailImage = DcUtils.generateThumbnailFromVideo(url: URL(fileURLWithPath: path, isDirectory: false))
                    if let thumbnailImage = thumbnailImage {
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            self.contentImageView.image = thumbnailImage
                            self.setAspectRatio(image: thumbnailImage)
                            ThumbnailCache.shared.storeImage(image: thumbnailImage, key: path)
                        }
                    }
                }
            }
            self.isHidden = false
        } else {
            isHidden = true
        }
    }

    override public func cancel() {
        contentImageView.sd_cancelCurrentImageLoad()
        contentImageView.image = nil
        delegate?.onCancelAttachment()
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
}
