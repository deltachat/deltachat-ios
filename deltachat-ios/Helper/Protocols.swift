import UIKit

protocol QrCodeReaderDelegate: AnyObject {
    func handleQrCode(_ viewController: UIViewController, qrCode: String)
}

protocol ContactListDelegate: AnyObject {
    func deviceContactsImported()
}
