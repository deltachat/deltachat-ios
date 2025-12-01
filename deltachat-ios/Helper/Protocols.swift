import UIKit

protocol QrCodeReaderDelegate: AnyObject {
    func handleQrCode(_ qrCode: String)
}
