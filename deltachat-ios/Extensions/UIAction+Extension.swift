import DcCore
import UIKit

extension UIAction {
    static func menuAction<T>(localizationKey: String, attributes: UIAction.Attributes = [], systemImageName: String, with arg: T, action: @escaping (T) -> Void) -> UIAction {
        return menuAction(localizationKey: localizationKey, attributes: attributes, image: UIImage(systemName: systemImageName), with: arg, action: action)
    }

    static func menuAction<T>(localizationKey: String, attributes: UIAction.Attributes = [], image: UIImage?, with arg: T, action: @escaping (T) -> Void) -> UIAction {
        return UIAction(
            title: String.localized(localizationKey),
            image: image,
            attributes: attributes,
            handler: { _ in
                DispatchQueue.main.async {
                    action(arg)
                }
            }
        )
    }
}

extension UIAction {
    static func archiveChat(_ dcChat: DcChat, dcContext: DcContext, navigate vc: UIViewController) -> UIAction {
        UIAction(
            title: String.localized(dcChat.isArchived ? "menu_unarchive_chat" : "menu_archive_chat"),
            image: UIImage(systemName: dcChat.isArchived ? "tray.and.arrow.up" : "tray.and.arrow.down"),
            handler: { [weak vc] _ in
                let archivedBefore = dcChat.isArchived
                if !archivedBefore {
                    NotificationManager.removeNotificationsForChat(dcChat.id, accountId: dcContext.id)
                }
                dcContext.archiveChat(chatId: dcChat.id, archive: !archivedBefore)
                vc?.navigationController?.popToRootViewController(animated: true)
            }
        )
    }

    static func leaveChat(_ dcChat: DcChat, dcContext: DcContext, presentAlertsOn vc: UIViewController) -> UIAction {
        if dcChat.mustLeaveBeforeDelete(dcContext) {
            let leaveText = dcChat.isInBroadcast ? "menu_leave_channel" : "menu_leave_group"
            return UIAction(
                title: String.localized(leaveText),
                image: UIImage(systemName: "rectangle.portrait.and.arrow.right"),
                attributes: [.destructive],
                handler: { [weak vc] _ in
                    let alert = UIAlertController(title: String.localized("ask_leave_group"), message: nil, preferredStyle: .safeActionSheet)
                    alert.addAction(UIAlertAction(title: String.localized(leaveText), style: .destructive, handler: { _ in
                        _ = dcContext.removeContactFromChat(chatId: dcChat.id, contactId: Int(DC_CONTACT_ID_SELF))
                    }))
                    alert.addAction(UIAlertAction(title: String.localized("menu_leave_and_delete"), style: .destructive, handler: { [weak vc] _ in
                        _ = dcContext.removeContactFromChat(chatId: dcChat.id, contactId: Int(DC_CONTACT_ID_SELF))
                        dcContext.deleteReferencesAndChat(chatId: dcChat.id)
                        vc?.navigationController?.popToRootViewController(animated: true)
                    }))
                    alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel))
                    vc?.present(alert, animated: true, completion: nil)
                }
            )
        } else {
            return UIAction(
                title: String.localized("menu_delete_chat"),
                image: UIImage(systemName: "trash"),
                attributes: [.destructive],
                handler: { [weak vc] _ in
                    let alert = UIAlertController(title: nil, message: String.localizedStringWithFormat(String.localized("ask_delete_named_chat"), dcChat.name), preferredStyle: .safeActionSheet)
                    alert.addAction(UIAlertAction(title: String.localized("delete_for_me"), style: .destructive, handler: { [weak vc] _ in
                        dcContext.deleteReferencesAndChat(chatId: dcChat.id)
                        vc?.navigationController?.popToRootViewController(animated: true)
                    }))
                    alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
                    vc?.present(alert, animated: true, completion: nil)
                }
            )
        }
    }
}
