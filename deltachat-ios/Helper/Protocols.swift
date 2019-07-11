import UIKit

protocol Coordinator: class {
  // var rootViewController: UIViewController { get }
  // func start()
}

protocol QrCodeReaderDelegate: class {
  func handleQrCode(_ code: String)
}

protocol ContactListDelegate: class {
  func accessGranted()
  func accessDenied()
  func deviceContactsImported()
}

protocol ChatDisplayer: class {
  func displayNewChat(contactId: Int)
  func displayChatForId(chatId: Int)
}
