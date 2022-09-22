import UIKit
import Photos
import MobileCoreServices

protocol MediaPickerDelegate: class {
    func onImageSelected(image: UIImage)
    func onImageSelected(url: NSURL)
    func onVideoSelected(url: NSURL)
    func onVoiceMessageRecorded(url: NSURL)
    func onVoiceMessageRecorderClosed()
    func onDocumentSelected(url: NSURL)
    func onSelectionCancelled()
}

extension MediaPickerDelegate {
    func onImageSelected(image: UIImage) {
        logger.debug("image selected")
    }
    func onImageSelected(url: NSURL) {
        logger.debug("image selected: ", url.path ?? "unknown")
    }
    func onVideoSelected(url: NSURL) {
        logger.debug("video selected: ", url.path ?? "unknown")
    }
    func onVoiceMessageRecorded(url: NSURL) {
        logger.debug("voice message recorded: \(url)")
    }
    func onVoiceMessageRecorderClosed() {
        logger.debug("Voice Message recorder closed.")
    }
    func onDocumentSelected(url: NSURL) {
        logger.debug("document selected: \(url)")
    }
    func onSelectionCancelled() {
        logger.debug("media selection cancelled")
    }
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

    private weak var navigationController: UINavigationController?
    weak var delegate: MediaPickerDelegate?

    init(navigationController: UINavigationController?) {
        // it does not make sense to give nil here, but it makes construction easier
        self.navigationController = navigationController
    }

    func showVoiceRecorder() {
        let audioRecorderController = AudioRecorderController()
        audioRecorderController.delegate = self
        // audioRecorderController.maximumRecordDuration = 1200
        let audioRecorderNavController = UINavigationController(rootViewController: audioRecorderController)

        navigationController?.present(audioRecorderNavController, animated: true, completion: nil)
    }

    func showPhotoVideoLibrary() {
        if PHPhotoLibrary.authorizationStatus() != .authorized {
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async { [weak self] in
                    switch status {
                    case  .denied, .notDetermined, .restricted:
                        print("denied")
                    case .authorized, .limited:
                        self?.presentPhotoVideoLibrary()
                    }
                }
            }
        } else {
            presentPhotoVideoLibrary()
        }
    }

    func showDocumentLibrary(selectFolder: Bool = false) {
        let documentPicker: UIDocumentPickerViewController
        if selectFolder {
            if #available(iOS 15.0, *) {
                documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.archive], asCopy: false)
            } else {
                documentPicker = UIDocumentPickerViewController(documentTypes: [kUTTypeArchive] as [String], in: .open)
            }
        } else {
            if #available(iOS 15.0, *) {
                let types = [UTType.pdf, UTType.text, UTType.rtf, UTType.spreadsheet, UTType.vCard, UTType.zip, UTType.image, UTType.data]
                documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
            } else {
                let types = [kUTTypePDF, kUTTypeText, kUTTypeRTF, kUTTypeSpreadsheet, kUTTypeVCard, kUTTypeZipArchive, kUTTypeImage, kUTTypeData]
                documentPicker = UIDocumentPickerViewController(documentTypes: types as [String], in: .import)
            }
        }
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        documentPicker.modalPresentationStyle = .formSheet
        navigationController?.present(documentPicker, animated: true, completion: nil)
    }

    private func presentPhotoVideoLibrary() {
        let mediaTypes = [
            kUTTypeMovie as String,
            kUTTypeVideo as String,
            kUTTypeImage as String
        ]
        showPhotoLibrary(allowsCropping: false, mediaTypes: mediaTypes)
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
            navigationController?.present(imagePickerController, animated: true, completion: nil)
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

        if let type = info[.mediaType] as? String, let mediaType = PickerMediaType(rawValue: type) {

            switch mediaType {
            case .video:
                if let videoUrl = info[.mediaURL] as? URL {
                    handleVideoUrl(url: videoUrl)
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
    }
}

extension MediaPicker: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        let url = urls[0] as NSURL
        self.delegate?.onDocumentSelected(url: url)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        self.delegate?.onSelectionCancelled()
    }
}
