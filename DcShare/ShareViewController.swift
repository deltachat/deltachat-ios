import UIKit
import Social
import DcCore

class ShareViewController: SLComposeServiceViewController {

    let dcContext = DcContext.shared

    override func presentationAnimationDidFinish() {
        let dbHelper = DatabaseHelper()
        if dbHelper.currentDatabaseLocation == dbHelper.sharedDbFile {
            dcContext.openDatabase(dbFile: dbHelper.sharedDbFile)
        } else {
            cancel()
        }
    }

    override func isContentValid() -> Bool {
        // Do validation of contentText and/or NSExtensionContext attachments here
        return  !(contentText?.isEmpty ?? true)
    }

    override func didSelectPost() {
        // This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.

        let selfchatId = dcContext.getChatIdByContactId(contactId: Int(DC_CONTACT_ID_SELF))
        let message = DcMsg(viewType: DC_MSG_TEXT)
        message.text = self.contentText
        message.sendInChat(id: selfchatId)

        dcContext.closeDatabase()
        // Inform the host that we're done, so it un-blocks its UI. Note: Alternatively you could call super's -didSelectPost, which will similarly complete the extension context.
        self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }

    override func configurationItems() -> [Any]! {
        // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
        return []
    }

}
