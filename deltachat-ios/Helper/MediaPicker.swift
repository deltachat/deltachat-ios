import UIKit
import Photos
import MobileCoreServices
import ALCameraViewController
import IQAudioRecorderController

protocol MediaPickerDelegate: class {
    func onImageSelected(image: UIImage)
    func onImageSelected(url: NSURL)
    func onVideoSelected(url: NSURL)
    func onVoiceMessageRecorded(url: NSURL)
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
}

class MediaPicker: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate, AudioRecorderControllerDelegate {

    private let navigationController: UINavigationController
    private weak var delegate: MediaPickerDelegate?

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }


    func showVoiceRecorder(delegate: MediaPickerDelegate) {
        self.delegate = delegate
        let audioRecorderController = AudioRecorderController()
        audioRecorderController.delegate = self
        //audioRecorderController.maximumRecordDuration = 1200
        let audioRecorderNavController = UINavigationController(rootViewController: audioRecorderController)

        navigationController.present(audioRecorderNavController, animated: true, completion: nil)
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

    private func presentPhotoVideoLibrary(delegate: MediaPickerDelegate) {
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            let videoPicker = UIImagePickerController()
            videoPicker.title = String.localized("gallery")
            videoPicker.delegate = self
            videoPicker.sourceType = .photoLibrary
            videoPicker.mediaTypes = [kUTTypeMovie as String,
                                      kUTTypeVideo as String,
                                      kUTTypeImage as String]
            self.delegate = delegate
            navigationController.present(videoPicker, animated: true, completion: nil)
        }
    }

    func showPhotoGallery(delegate: MediaPickerDelegate) {
        let croppingParameters = CroppingParameters(isEnabled: true,
                                                    allowResizing: true,
                                                    allowMoving: true,
                                                    minimumSize: CGSize(width: 70, height: 70))

        let controller = CameraViewController.imagePickerViewController(croppingParameters: croppingParameters,
                                                                        completion: { [weak self] image, _ in
                                                                            if let image = image {
                                                                                self?.delegate?.onImageSelected(image: image)
                                                                            }
                                                                            self?.navigationController.dismiss(animated: true, completion: nil)})
        self.delegate = delegate
        navigationController.present(controller, animated: true, completion: nil)
    }

    func showCamera(delegate: MediaPickerDelegate, allowCropping: Bool) {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            var croppingParameters: CroppingParameters = CroppingParameters()
            if allowCropping {
                croppingParameters = CroppingParameters(isEnabled: true,
                allowResizing: true,
                allowMoving: true,
                minimumSize: CGSize(width: 70, height: 70))
            }

            let cameraViewController = CameraViewController(croppingParameters: croppingParameters,
                                                            allowsLibraryAccess: false,
                                                            allowsSwapCameraOrientation: true,
                                                            allowVolumeButtonCapture: false,
                                                            completion: { [weak self] image, _ in
                                                                if let image = image {
                                                                    self?.delegate?.onImageSelected(image: image)
                                                                }
                                                                self?.navigationController.dismiss(animated: true, completion: nil)})
            self.delegate = delegate
            navigationController.present(cameraViewController, animated: true, completion: nil)
        } else {
            let alert = UIAlertController(title: String.localized("chat_camera_unavailable"), message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("ok"), style: .cancel, handler: { _ in
                self.navigationController.dismiss(animated: true, completion: nil)
            }))
            navigationController.present(alert, animated: true, completion: nil)
        }
    }

    func showCamera(delegate: MediaPickerDelegate) {
        showCamera(delegate: delegate, allowCropping: true)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        if let videoUrl = info[UIImagePickerController.InfoKey.mediaURL] as? NSURL {
            self.delegate?.onVideoSelected(url: videoUrl)
        } else if let imageUrl = info[UIImagePickerController.InfoKey.imageURL] as? NSURL {
            self.delegate?.onImageSelected(url: imageUrl)
        }
        navigationController.dismiss(animated: true, completion: nil)
    }

    func didFinishAudioAtPath(path: String) {
        let url = NSURL(fileURLWithPath: path)
        self.delegate?.onVoiceMessageRecorded(url: url)
    }

}
