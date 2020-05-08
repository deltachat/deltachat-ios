import UIKit

protocol Coordinator: class {
}

protocol QrCodeReaderDelegate: class {
    func handleQrCode(_ code: String)
}

protocol ContactListDelegate: class {
    func accessGranted()
    func accessDenied()
    func deviceContactsImported()
}
