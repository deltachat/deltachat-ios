import UIKit
import SDWebImage

class MediaPreview: UIView {

    lazy var contentImageView: SDAnimatedImageView = {
        let imageView = SDAnimatedImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        imageView.isUserInteractionEnabled = true
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()

    /// The play button view to display on video messages.
    open lazy var playButtonView: PlayButtonView = {
        let playButtonView = PlayButtonView()
        playButtonView.isHidden = true
        translatesAutoresizingMaskIntoConstraints = false
        return playButtonView
    }()

    

    init() {
        super.init(frame: .zero)
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupSubviews() {

    }
}
