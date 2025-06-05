import UIKit
import PhotosUI
import Photos
import MobileCoreServices
import DcCore

protocol MediaPickerDelegate: AnyObject {
    // onImageSelected() and onVideoSelected() are called in response to showCamera() or showGallery(allowCropping: true)
    func onImageSelected(image: UIImage)
    func onImageSelected(url: NSURL)
    func onVideoSelected(url: NSURL)

    // onMediaSelected() is called in responce to showGallery()
    func onMediaSelected(mediaPicker: MediaPicker, itemProviders: [NSItemProvider], sendAsFile: Bool)

    // onVoiceMessageRecorded*() are called in response to showVoiceRecorder()
    func onVoiceMessageRecorded(url: NSURL)
    func onVoiceMessageRecorderClosed()

    // onDocumentSelected() us called in response to showDocumentLibrary()
    func onDocumentSelected(url: NSURL)
}

extension MediaPickerDelegate {
    // stub functions so that callers do not need to implement all delegates
    func onImageSelected(image: UIImage) { }
    func onImageSelected(url: NSURL) { }
    func onVideoSelected(url: NSURL) { }
    func onMediaSelected(mediaPicker: MediaPicker, itemProviders: [NSItemProvider], sendAsFile: Bool) {}
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
    private var sendAsFile: Bool = false
    weak var delegate: MediaPickerDelegate?

    init(dcContext: DcContext, navigationController: UINavigationController?) {
        self.dcContext = dcContext
        self.navigationController = navigationController
    }

    func showVoiceRecorder() {
        let audioRecorderController = AudioRecorderController(dcContext: dcContext)
        audioRecorderController.delegate = self
        let audioRecorderNavController = UINavigationController(rootViewController: audioRecorderController)

        if #available(iOS 15.0, *) {
            if let sheet = audioRecorderNavController.sheetPresentationController {
                if #available(iOS 16.0, *) {
                    let customDetent = UISheetPresentationController.Detent.custom(identifier: .init("thirtyPercent")) { context in
                        return context.maximumDetentValue * 0.3
                    }
                    sheet.detents = [customDetent]
                } else {
                    sheet.detents = [.medium()]
                }
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

    func showFilesLibrary() {
        let alert = UIAlertController(title: nil, message: String.localized("files_attach_hint"), preferredStyle: .safeActionSheet)

        let fileAction = UIAlertAction(title: String.localized("choose_from_files"), style: .default) { [weak self] _ in
            self?.showDocumentLibrary()
        }
        fileAction.setValue(UIImage(systemName: "doc"), forKey: "image")
        alert.addAction(fileAction)

        let galleryAction = UIAlertAction(title: String.localized("choose_from_gallery"), style: .default) { [weak self] _ in
            self?.showGallery(sendAsFile: true)
        }
        galleryAction.setValue(UIImage(systemName: "photo.on.rectangle"), forKey: "image")
        alert.addAction(galleryAction)

        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel))
        navigationController?.present(alert, animated: true)
    }

    func showDocumentLibrary(selectBackupArchives: Bool = false) {
        let documentPicker: UIDocumentPickerViewController
        if selectBackupArchives {
            documentPicker = .init(forOpeningContentTypes: [UTType.archive], asCopy: false)
        } else {
            documentPicker = .init(forOpeningContentTypes: [.pdf, .text, .rtf, .spreadsheet, .vCard, .zip, .image, .data], asCopy: true)
        }
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        documentPicker.modalPresentationStyle = .formSheet
        navigationController?.present(documentPicker, animated: true)
    }

    func showGallery(allowCropping: Bool = false, sendAsFile: Bool = false) {
        // we have to use older UIImagePickerController as well as newer PHPickerViewController:
        // - only the older allows cropping and only the newer allows mutiple selection
        // - the newer results in weird errors on older OS, see discussion at https://github.com/deltachat/deltachat-ios/pull/2678
        self.sendAsFile = sendAsFile
        if !allowCropping {
            var configuration = PHPickerConfiguration(photoLibrary: .shared())
            configuration.filter = nil
            // as raw files are 10~100 times larger and full inboxes are bad,
            // sending raw files should be explicitly selected - also that shows size in staging area and makes difference clear
            configuration.selectionLimit = sendAsFile ? 1 : 0
            configuration.preferredAssetRepresentationMode = .compatible
            let imagePicker = PHPickerViewController(configuration: configuration)
            imagePicker.delegate = self
            navigationController?.present(imagePicker, animated: true)
        } else {
            if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
                let imagePickerController = UIImagePickerController()
                imagePickerController.delegate = self
                imagePickerController.sourceType = .photoLibrary
                imagePickerController.mediaTypes = [kUTTypeImage as String]
                imagePickerController.allowsEditing = true
                navigationController?.present(imagePickerController, animated: true)
            } else {
                navigationController?.logAndAlert(error: "Gallery not available.")
            }
        }
    }

    func showCamera(allowCropping: Bool = false, supportedMediaTypes: CameraMediaTypes = .allAvailable) {
        self.sendAsFile = false
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
        assert(Thread.isMainThread)
        let itemProviders = results.compactMap { $0.itemProvider }
        picker.dismiss(animated: true)
        delegate?.onMediaSelected(mediaPicker: self, itemProviders: itemProviders, sendAsFile: sendAsFile)
    }
}

extension MediaPicker: UIImagePickerControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        if let type = info[.mediaType] as? String, let mediaType = PickerMediaType(rawValue: type) {
            switch mediaType {
            case .video:
                // selected from gallery or camera
                if let url = info[.mediaURL] as? NSURL {
                    self.delegate?.onVideoSelected(url: url)
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
