import UIKit
import PhotosUI
import Photos
import MobileCoreServices
import DcCore

protocol MediaPickerDelegate: AnyObject {
    func onImageSelected(image: UIImage)
    func onImageSelected(url: NSURL)
    func onVideoSelected(url: NSURL)
    func onMediaSelected(mediaPicker: MediaPicker, itemProviders: [NSItemProvider])
    func onVoiceMessageRecorded(url: NSURL)
    func onVoiceMessageRecorderClosed()
    func onDocumentSelected(url: NSURL)
}

extension MediaPickerDelegate {
    func onImageSelected(image: UIImage) { }
    func onImageSelected(url: NSURL) { }
    func onVideoSelected(url: NSURL) { }
    func onMediaSelected(mediaPicker: MediaPicker, itemProviders: [NSItemProvider]) {}
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
        showPhotoLibrary(allowsCropping: true, filter: .any(of: [.images])) // used mainly for avatar-selection, allow cropping therefore
    }

    func showPhotoLibrary(allowsCropping: Bool = false, filter: PHPickerFilter? = nil) {
        // we have to use older UIImagePickerController as well as newer PHPickerViewController -
        // only the older allows cropping and only the newer allows mutiple selection :/
        if allowsCropping {
            if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
                let imagePickerController = UIImagePickerController()
                imagePickerController.delegate = self
                imagePickerController.sourceType = .photoLibrary
                imagePickerController.mediaTypes = [kUTTypeImage as String]
                imagePickerController.allowsEditing = allowsCropping
                navigationController?.present(imagePickerController, animated: true)
            } else {
                navigationController?.logAndAlert(error: "Gallery not available.")
            }
        } else {
            var configuration = PHPickerConfiguration(photoLibrary: .shared())
            configuration.filter = filter
            configuration.selectionLimit = 0
            configuration.preferredAssetRepresentationMode = .compatible
            let imagePicker = PHPickerViewController(configuration: configuration)
            imagePicker.delegate = self
            navigationController?.present(imagePicker, animated: true)
        }
    }

    func showCamera(allowCropping: Bool = false, supportedMediaTypes: CameraMediaTypes = .allAvailable) {
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
            navigationController?.logAndAlert(error: String.localized("chat_camera_unavailable"))
        }
    }
}

extension MediaPicker: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        let itemProviders = results.compactMap { $0.itemProvider }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            picker.dismiss(animated: true)
            self.delegate?.onMediaSelected(mediaPicker: self, itemProviders: itemProviders)
        }
    }
}

extension MediaPicker: UIImagePickerControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        if let type = info[.mediaType] as? String, let mediaType = PickerMediaType(rawValue: type) {
            switch mediaType {
            case .video:
                // selected from gallery or camera
                if let url = info[.mediaURL] as? URL {
                    url.convertToMp4(completionHandler: { url, error in
                        if let url {
                            self.delegate?.onVideoSelected(url: (url as NSURL))
                        } else if let error {
                            self.navigationController?.logAndAlert(error: error.localizedDescription)
                        }
                    })
                }
            case .image:
                if let image = info[.editedImage] as? UIImage {
                    // selected from camera and edtied
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
