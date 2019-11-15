import UIKit
import Photos
import MobileCoreServices

protocol MediaPickerDelegate: class {
    func onMediaSelected(url: NSURL)
    func onDismiss()
}

class MediaPicker: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    private let navigationController: UINavigationController
    private weak var delegate: MediaPickerDelegate?

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func showPhotoLibrary(delegate: MediaPickerDelegate) {
        if PHPhotoLibrary.authorizationStatus() != .authorized {
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    [weak self] in
                    switch status {
                    case  .denied, .notDetermined, .restricted:
                        print("denied")
                    case .authorized:
                        self?.presentPhotoLibrary(delegate: delegate)
                    }
                }
            }
        } else {
            self.presentPhotoLibrary(delegate: delegate)
        }
    }

    private func presentPhotoLibrary(delegate: MediaPickerDelegate) {
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            let photoPicker = UIImagePickerController()
            photoPicker.title = String.localized("photo")
            photoPicker.delegate = self
            photoPicker.sourceType = .photoLibrary
            photoPicker.allowsEditing = false
            photoPicker.mediaTypes = UIImagePickerController.availableMediaTypes(for: .photoLibrary) ?? []
            navigationController.present(photoPicker, animated: true, completion: nil)
            self.delegate = delegate
        }
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        if let imageUrl = info[UIImagePickerController.InfoKey.imageURL] as? NSURL {
            logger.debug("image selected: \(imageUrl)")
            delegate?.onMediaSelected(url: imageUrl)
        } else {
            logger.warning("could not select image")
        }
        navigationController.dismiss(animated: true, completion: delegate?.onDismiss)
    }

}
