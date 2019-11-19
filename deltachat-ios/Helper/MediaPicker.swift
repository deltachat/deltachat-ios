import UIKit
import Photos
import MobileCoreServices
import ALCameraViewController

protocol MediaPickerDelegate: class {
    //func onMediaSelected(url: NSURL)
    func onImageSelected(image: UIImage)
    func onDismiss()
}

class MediaPicker: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    private let navigationController: UINavigationController
    private weak var delegate: MediaPickerDelegate?

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func showImageCropper(delegate: MediaPickerDelegate) {
        let croppingParameters = CroppingParameters(isEnabled: true,
                                                    allowResizing: true,
                                                    allowMoving: true,
                                                    minimumSize: CGSize(width: 70, height: 70))

        let controller = CameraViewController.imagePickerViewController(croppingParameters: croppingParameters,
                                                                        completion: { [weak self] image, _ in
                                                                            if let image = image {
                                                                                self?.delegate?.onImageSelected(image: image)
                                                                            }
                                                                            self?.navigationController.dismiss(animated: true, completion: delegate.onDismiss)})
        self.delegate = delegate
        navigationController.present(controller, animated: true, completion: nil)
    }

    func showCamera(delegate: MediaPickerDelegate) {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let croppingParameters = CroppingParameters(isEnabled: true,
            allowResizing: true,
            allowMoving: true,
            minimumSize: CGSize(width: 70, height: 70))
            let cameraViewController = CameraViewController(croppingParameters: croppingParameters,
                                                            allowsLibraryAccess: false,
                                                            allowsSwapCameraOrientation: true,
                                                            allowVolumeButtonCapture: false,
                                                            completion: { [weak self] image, _ in
                                                                if let image = image {
                                                                    self?.delegate?.onImageSelected(image: image)
                                                                }
                                                                self?.navigationController.dismiss(animated: true, completion: self?.delegate?.onDismiss)})
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

}
