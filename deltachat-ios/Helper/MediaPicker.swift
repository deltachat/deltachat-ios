import UIKit
import Photos
import MobileCoreServices
import KK_ALCameraViewController

protocol MediaPickerDelegate: class {
    func onImageSelected(image: UIImage)
    func onImageSelected(url: NSURL)
    func onVideoSelected(url: NSURL)
    func onVoiceMessageRecorded(url: NSURL)
    func onDocumentSelected(url: NSURL)
}

extension MediaPickerDelegate {
    func onImageSelected(url: NSURL) {
        logger.debug("image selected: ", url.path ?? "unknown")
    }
    func onVideoSelected(url: NSURL) {
        logger.debug("video selected: ", url.path ?? "unknown")
    }
    func onVoiceMessageRecorded(url: NSURL) {
        logger.debug("voice message recorded: \(url)")
    }
    func onDocumentSelected(url: NSURL) {
        logger.debug("document selected: \(url)")
    }
}

class MediaPicker: NSObject, UINavigationControllerDelegate, AudioRecorderControllerDelegate {

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

    func showVoiceRecorder(delegate: MediaPickerDelegate) {
        self.delegate = delegate
        let audioRecorderController = AudioRecorderController()
        audioRecorderController.delegate = self
        //audioRecorderController.maximumRecordDuration = 1200
        let audioRecorderNavController = UINavigationController(rootViewController: audioRecorderController)

        navigationController?.present(audioRecorderNavController, animated: true, completion: nil)
    }

    func showPhotoVideoLibrary(delegate: MediaPickerDelegate) {
        if PHPhotoLibrary.authorizationStatus() != .authorized {
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    [weak self] in
                    switch status {
                    case  .denied, .notDetermined, .restricted:
                        print("denied")
                    case .authorized:
                        self?.presentPhotoVideoLibrary(delegate: delegate)
                    }
                }
            }
        } else {
            presentPhotoVideoLibrary(delegate: delegate)
        }
    }

    func showDocumentLibrary(delegate: MediaPickerDelegate) {
        let types = [kUTTypePDF, kUTTypeText, kUTTypeRTF, kUTTypeSpreadsheet, kUTTypeVCard, kUTTypeZipArchive, kUTTypeImage]
        let documentPicker = UIDocumentPickerViewController(documentTypes: types as [String], in: .import)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        documentPicker.modalPresentationStyle = .formSheet
        self.delegate = delegate
        navigationController?.present(documentPicker, animated: true, completion: nil)
    }

    private func presentPhotoVideoLibrary(delegate: MediaPickerDelegate) {
        let mediaTypes = [
            kUTTypeMovie as String,
            kUTTypeVideo as String,
            kUTTypeImage as String
        ]
        showPhotoLibrary(mediaTypes: mediaTypes)
    }

    func showPhotoGallery() {
        let mediaType = [kUTTypeImage as String]
        showPhotoLibrary(mediaTypes: mediaType)
    }

    private func showPhotoLibrary(mediaTypes: [String]) {
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.sourceType = .photoLibrary
            imagePicker.mediaTypes = mediaTypes
            navigationController?.present(imagePicker, animated: true, completion: nil)
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
            if allowCropping {
                imagePickerController.allowsEditing = true
            }
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
                var image: UIImage?
                if let editedImage = info[.editedImage] as? UIImage {
                    image = editedImage
                } else if let originalImage = info[.originalImage] as? UIImage {
                    image = originalImage
                }
                // orientation fix needed for images picked from photoGallery
                if let image = image?.upOrientationImage() {
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

    func didFinishAudioAtPath(path: String) {
        let url = NSURL(fileURLWithPath: path)
        self.delegate?.onVoiceMessageRecorded(url: url)
    }

}

extension MediaPicker: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        let url = urls[0] as NSURL
        self.delegate?.onDocumentSelected(url: url)
    }
}
