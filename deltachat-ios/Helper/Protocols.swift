import UIKit

protocol QrCodeReaderDelegate: AnyObject {
    func handleQrCode(_ code: String)
}

protocol ContactListDelegate: AnyObject {
    func deviceContactsImported()
}
