import UIKit

protocol QrCodeReaderDelegate: AnyObject {
    func handleQrCode(_ code: String)
}

protocol ContactListDelegate: AnyObject {
    func accessGranted()
    func accessDenied()
    func deviceContactsImported()
}
