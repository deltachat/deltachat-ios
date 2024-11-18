import UIKit

protocol QrCodeReaderDelegate: AnyObject {
    func handleQrCode(_ qrCode: String)
}

protocol ContactListDelegate: AnyObject {
    func deviceContactsImported()
}
