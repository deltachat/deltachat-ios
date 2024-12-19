import UIKit
import DcCore
import PassKit

public class FileView: UIView {

    private var imageWidthConstraint: NSLayoutConstraint?
    private var imageHeightConstraint: NSLayoutConstraint?

    public var horizontalLayout: Bool {
        get {
            return fileStackView.axis == .horizontal
        }
        set {
            if newValue {
                fileStackView.axis = .horizontal
                imageWidthConstraint?.isActive = true
                imageHeightConstraint?.isActive = true
                fileStackView.alignment = .center
            } else {
                fileStackView.axis = .vertical
                imageWidthConstraint?.isActive = false
                imageHeightConstraint?.isActive = false
                fileStackView.alignment = .leading
            }
        }
    }

    // allow to automatically switch between small and large preview of a file,
    // depending on the file type, if false the view will be configured according to horizontalLayout Bool
    public var allowLayoutChange: Bool = true

    private lazy var defaultImage: UIImage = {
        let image = UIImage(named: "ic_attach_file_36pt")
        return image!
    }()
    
    private func deviceSupportsAddingPass() -> Bool {
        guard PKPassLibrary.isPassLibraryAvailable() else {
            logger.warning("Pass Library is not available.")
            return false
        }
        return PKAddPassesViewController.canAddPasses()
    }
    
    private var walletPass: PKPass?
    
    private lazy var addToWalletButton: UIButton = {
        let addToWalletButton = PKAddPassButton(addPassButtonStyle: .black)
        addToWalletButton.addTarget(self, action: #selector(addToWalletAction), for: .touchDown)
        return addToWalletButton
    }()
    
    @IBAction func addToWalletAction() {
        if let pass = walletPass {
            guard let addPassesViewController = PKAddPassesViewController(pass: pass) else {
                logger.error("Error creating PKAddPassesViewController")
                return
            }
            self.window?.rootViewController?.present(addPassesViewController, animated: true)
        } else {
            logger.error("no wallet pass available")
        }
    }

    private lazy var fileStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [fileImageView, fileMetadataStackView])
        stackView.axis = .horizontal
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.spacing = 6
        return stackView
    }()

    lazy var fileImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        isAccessibilityElement = false
        return imageView
    }()

    private lazy var fileMetadataStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [fileTitle, fileSubtitle])
        stackView.axis = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.clipsToBounds = true
        return stackView
    }()

    lazy var fileTitle: UILabel = {
        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = false
        return title
    }()

    private lazy var fileSubtitle: UILabel = {
        let subtitle = UILabel()
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        subtitle.numberOfLines = 1
        isAccessibilityElement = false
        return subtitle
    }()

    convenience init() {
        self.init(frame: .zero)

    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupSubviews()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }


    func setupSubviews() {
        addSubview(fileStackView)
        fileStackView.fillSuperview()
        imageWidthConstraint = fileImageView.constraintWidthTo(50)
        imageHeightConstraint = fileImageView.constraintHeightTo(50 * 1.3, priority: .defaultLow)
        horizontalLayout = true
    }

    public func configure(message: DcMsg) {
        if message.type == DC_MSG_WEBXDC {
           configureWebxdc(message: message)
        } else if message.type == DC_MSG_FILE || message.isUnsupportedMediaFile {
            configureFile(message: message)
            if let fileURL = message.fileURL {
                if fileURL.pathExtension == "pkpass" {
                    do {
                        let passData = try Data(contentsOf: fileURL)
                        let pass = try PKPass(data: passData)
                        self.walletPass = pass
                        
                        fileTitle.text = pass.localizedName
                        fileSubtitle.text = pass.localizedDescription
                        fileSubtitle.numberOfLines = 2
                        
                        // Make sure text is visible in both dark and light mode
                        // TODO: ideally we would either have a different design where text is not overlayed on item, or make text color dependent on color of icon (though be aware that icon could have both dark and light areas)
                        fileTitle.textColor = .white
                        fileSubtitle.textColor = .white
                        fileTitle.shadowColor = .black
                        fileSubtitle.shadowColor = .black
                                                
                        let backgroundImageView = UIImageView(frame: self.bounds)
                        // somehow we only get low res icon (iMessage shows a high res image)
                        // IDEA: find out how to get high res image
                        backgroundImageView.image = pass.icon
                        backgroundImageView.contentMode = .scaleAspectFill
                        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
                        self.insertSubview(backgroundImageView, at: 0)
                        NSLayoutConstraint.activate([
                            backgroundImageView.topAnchor.constraint(equalTo: self.topAnchor),
                            backgroundImageView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
                            backgroundImageView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
                            backgroundImageView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
                        ])
                        
                        self.clipsToBounds = true
                        self.layer.cornerRadius = 10.0
                        
                        fileImageView.isHidden = true

                        fileMetadataStackView.addArrangedSubview(addToWalletButton)
                    } catch {
                        print("Error loading pass: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            logger.error("Configuring message failed")
        }
    }

    private func configureWebxdc(message: DcMsg) {
        fileImageView.layer.cornerRadius = 8
        let dict = message.getWebxdcInfoDict()
        if let iconfilePath = dict["icon"] as? String {
            let blob = message.getWebxdcBlob(filename: iconfilePath)
            if !blob.isEmpty {
                fileImageView.image = UIImage(data: blob)?.sd_resizedImage(with: CGSize(width: 175, height: 175), scaleMode: .aspectFill)
            }
        }

        let document = dict["document"] as? String ?? ""
        let summary = dict["summary"] as? String ?? ""
        let name = dict["name"] as? String ?? "ErrName" // name should not be empty

        fileTitle.numberOfLines = 1
        fileTitle.lineBreakMode = .byTruncatingTail
        fileTitle.font = UIFont.preferredFont(forTextStyle: .headline)
        fileSubtitle.font = UIFont.preferredFont(forTextStyle: .body)
        fileTitle.text = document.isEmpty ? name : "\(document) – \(name)"
        fileSubtitle.text = summary.isEmpty ? String.localized("webxdc_app") : summary
    }

    private func configureFile(message: DcMsg) {
        fileImageView.layer.cornerRadius = 0
        if let url = message.fileURL {
            generateThumbnailFor(url: url, placeholder: defaultImage)
        } else {
            fileImageView.image = defaultImage
            horizontalLayout = true
        }
        fileTitle.numberOfLines = 3
        fileTitle.lineBreakMode = .byCharWrapping
        fileTitle.font = UIFont.preferredFont(forTextStyle: .headline)
        fileSubtitle.font = UIFont.preferredFont(forTextStyle: .caption2)
        fileTitle.text = message.filename
        fileSubtitle.text = message.getPrettyFileSize()
    }

    public func configureAccessibilityLabel() -> String {
        var accessibilityFileTitle = ""
        var accessiblityFileSubtitle = ""
        if let fileTitleText = fileTitle.text {
            accessibilityFileTitle = fileTitleText
        }
        if let subtitleText = fileSubtitle.text {
            accessiblityFileSubtitle = subtitleText
        }
        
        return "\(accessibilityFileTitle), \(accessiblityFileSubtitle)"
    }

    public func prepareForReuse() {
        fileImageView.image = nil
    }

    private func generateThumbnailFor(url: URL, placeholder: UIImage?) {
        if let pdfThumbnail = DcUtils.thumbnailFromPdf(withUrl: url) {
            fileImageView.image = pdfThumbnail
            horizontalLayout = allowLayoutChange ? false : horizontalLayout
        } else {
            let controller = UIDocumentInteractionController(url: url)
            fileImageView.image = controller.icons.first ?? placeholder
            horizontalLayout = allowLayoutChange ? true : horizontalLayout
        }
    }


}
