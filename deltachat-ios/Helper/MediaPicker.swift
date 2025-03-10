import UIKit
import Photos
import MobileCoreServices
import DcCore

protocol MediaPickerDelegate: AnyObject {
    func onImageSelected(image: UIImage)
    func onImageSelected(url: NSURL)
    func onVideoSelected(url: NSURL)
    func onVoiceMessageRecorded(url: NSURL)
    func onVoiceMessageRecorderClosed()
    func onDocumentSelected(url: NSURL)
}

extension MediaPickerDelegate {
    func onImageSelected(image: UIImage) { }
    func onImageSelected(url: NSURL) { }
    func onVideoSelected(url: NSURL) { }
    func onVoiceMessageRecorded(url: NSURL) { }
    func onVoiceMessageRecorderClosed() { }
    func onDocumentSelected(url: NSURL) { }
}

class MediaPicker: NSObject, UINavigationControllerDelegate {

    enum CameraMediaTypes {
        case photo
        case allAvailable
    }

    enum PickerMediaType: String {
        case image = "public.image"
        case video = "public.movie"
     }

    private let dcContext: DcContext
    private weak var navigationController: UINavigationController?
    private var accountRecorderTransitionDelegate: PartialScreenModalTransitioningDelegate?
    weak var delegate: MediaPickerDelegate?

    init(dcContext: DcContext, navigationController: UINavigationController?) {
        self.dcContext = dcContext
        self.navigationController = navigationController
    }

    func showVoiceRecorder() {
        let audioRecorderController = AudioRecorderController(dcContext: dcContext)
        audioRecorderController.delegate = self
        // audioRecorderController.maximumRecordDuration = 1200
        let audioRecorderNavController = UINavigationController(rootViewController: audioRecorderController)

        if #available(iOS 15.0, *) {
            if let sheet = audioRecorderNavController.sheetPresentationController {
                sheet.detents = [.medium()]
                sheet.preferredCornerRadius = 20
            }
        } else {
            if let shownViewController = navigationController?.visibleViewController {
                accountRecorderTransitionDelegate = PartialScreenModalTransitioningDelegate(from: shownViewController, to: audioRecorderNavController)
                audioRecorderNavController.modalPresentationStyle = .custom
                audioRecorderNavController.transitioningDelegate = accountRecorderTransitionDelegate
            }
        }

        navigationController?.present(audioRecorderNavController, animated: true)
    }

    func showPhotoVideoLibrary() {
        let mediaTypes = [
            kUTTypeMovie as String,
            kUTTypeVideo as String,
            kUTTypeImage as String
        ]
        showPhotoLibrary(allowsCropping: false, mediaTypes: mediaTypes)
    }

    func showDocumentLibrary(selectFolder: Bool = false) {
        let documentPicker: UIDocumentPickerViewController
        if selectFolder {
            documentPicker = .init(forOpeningContentTypes: [UTType.archive], asCopy: false)
        } else {
            let types = [UTType.pdf, .text, .rtf, .spreadsheet, .vCard, .zip, .image, .data]
            documentPicker = .init(forOpeningContentTypes: types, asCopy: true)
        }
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        documentPicker.modalPresentationStyle = .formSheet
        navigationController?.present(documentPicker, animated: true)
    }

    func showPhotoGallery() {
        let mediaType = [kUTTypeImage as String]
        showPhotoLibrary(allowsCropping: true, mediaTypes: mediaType) // used mainly for avatar-selection, allow cropping therefore
    }

    private func showPhotoLibrary(allowsCropping: Bool, mediaTypes: [String]) {
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            let imagePickerController = UIImagePickerController()
            imagePickerController.delegate = self
            imagePickerController.sourceType = .photoLibrary
            imagePickerController.mediaTypes = mediaTypes
            imagePickerController.allowsEditing = allowsCropping
            navigationController?.present(imagePickerController, animated: true)
        }
    }

    func showCamera(allowCropping: Bool, supportedMediaTypes: CameraMediaTypes) {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let imagePickerController = UIImagePickerController()
            imagePickerController.sourceType = .camera
            imagePickerController.delegate = self
            let mediaTypes: [String]
            switch supportedMediaTypes {
            case .photo:
                mediaTypes = [PickerMediaType.image.rawValue]
            case .allAvailable:
                mediaTypes = UIImagePickerController.availableMediaTypes(for: .camera) ?? []
            }
            imagePickerController.allowsEditing = allowCropping
            imagePickerController.mediaTypes = mediaTypes
            imagePickerController.setEditing(true, animated: true)
            navigationController?.present(imagePickerController, animated: true, completion: nil)
        } else {
            let alert = UIAlertController(
                title: String.localized("chat_camera_unavailable"),
                message: nil,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: String.localized("ok"), style: .cancel, handler: { _ in
                self.navigationController?.dismiss(animated: true, completion: nil)
            }))
            navigationController?.present(alert, animated: true, completion: nil)
        }
    }

    func showCamera() {
        showCamera(allowCropping: false, supportedMediaTypes: .allAvailable)
    }

}

// MARK: - UIImagePickerControllerDelegate
extension MediaPicker: UIImagePickerControllerDelegate {

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        // This async basically makes sure the "Downloading from iCloud" alert is closed and
        // the keyboard is opened again if the search bar was active. This edge case causes a crash
        // in the KeyInput layer and prevents the keyboard from being opened until next launch (tested on iOS 16).
        // To test this:
        // - Remove this asyncAfter
        // - Open Chat
        // - Select text field so keyboard is open
        // - Attach
        // - Gallery
        // - Tap search bar in image picker
        // - Select an image that needs to be downloaded from iCloud
        // - Keyboard should come up but it does not (on iOS 16)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.handleImagePickerController(picker, didFinishPickingMediaWithInfo: info)
        }
    }

    private func handleImagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        if let type = info[.mediaType] as? String, let mediaType = PickerMediaType(rawValue: type) {

            switch mediaType {
            case .video:
                if let videoUrl = info[.mediaURL] as? URL {
                    self.handleVideoUrl(url: videoUrl)
                }
            case .image:
                if let image = info[.editedImage] as? UIImage {
                    //  selected from camera and edtied
                    self.delegate?.onImageSelected(image: image)
                } else if let imageURL = info[.imageURL] as? NSURL {
                    // selected from gallery
                    self.delegate?.onImageSelected(url: imageURL)
                } else if let image = info[.originalImage] as? UIImage {
                    // selected from camera
                    self.delegate?.onImageSelected(image: image)
                }
            }
        }
        picker.dismiss(animated: true, completion: nil)
    }

    func handleVideoUrl(url: URL) {
        url.convertToMp4(completionHandler: { url, error in
            if let url = url {
                self.delegate?.onVideoSelected(url: (url as NSURL))
            } else if let error = error {
                logger.error(error.localizedDescription)
                let alert = UIAlertController(title: String.localized("error"), message: nil, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: String.localized("ok"), style: .cancel, handler: { _ in
                    self.navigationController?.dismiss(animated: true, completion: nil)
                }))
                self.navigationController?.present(alert, animated: true, completion: nil)
            }
        })
    }
}

extension MediaPicker: AudioRecorderControllerDelegate {
    func didFinishAudioAtPath(path: String) {
        let url = NSURL(fileURLWithPath: path)
        self.delegate?.onVoiceMessageRecorded(url: url)
    }

    func didClose() {
        self.delegate?.onVoiceMessageRecorderClosed()
        accountRecorderTransitionDelegate = nil
    }
}

extension MediaPicker: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        let url = urls[0] as NSURL
        self.delegate?.onDocumentSelected(url: url)
    }
}
