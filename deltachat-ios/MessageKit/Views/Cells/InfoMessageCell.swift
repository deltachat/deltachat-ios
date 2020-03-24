import UIKit

open class InfoMessageCell: UICollectionViewCell {
    let label = MessageLabel()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        setupSubviews()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        setupSubviews()
    }

    open override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)
        if let attributes = layoutAttributes as? MessagesCollectionViewLayoutAttributes {
            label.textInsets = attributes.messageLabelInsets
            label.messageLabelFont = attributes.messageLabelFont
            label.backgroundColor = DcColors.systemMessageBackgroundColor
            let padding = (contentView.frame.width - attributes.messageContainerSize.width) / 2
            label.frame = CGRect(origin: CGPoint(x: padding, y: .zero), size: attributes.messageContainerSize)
        }
    }

    open override func prepareForReuse() {
        super.prepareForReuse()
        label.attributedText = nil
        label.text = nil
    }

    open func setupSubviews() {
        contentView.addSubview(label)
        label.layer.cornerRadius = 16
        label.layer.masksToBounds = true
        label.textAlignment = .center
    }

    open func configure(with message: MessageType, at indexPath: IndexPath, and collectionView: MessagesCollectionView) {
       label.configure {
            switch message.kind {
            case let .info(data):
                label.attributedText = data
            default:
                break
            }
        }
    }
}
