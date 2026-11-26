import DcCore
import SwiftUI

class QrPageController: UIViewController {
    private let dcContext: DcContext
    private let dcAccounts: DcAccounts
    lazy var moreButton = UIBarButtonItem(
        image: UIImage(systemName: .ellipsisNavigation()),
        menu: UIMenu { [weak self] in
            UIAction(title: String.localized("paste_from_clipboard"), image: UIImage(systemName: "doc.on.clipboard")) { [weak self] _ in
                self?.handleQrCode(UIPasteboard.general.string ?? "")
            }
            if self?.dcContext.forceEncryption == false {
                UIAction(title: String.localized("menu_new_classic_contact"), image: UIImage(systemName: "highlighter")) { [weak self] _ in
                    guard let self else { return }
                    self.navigationController?.pushViewController(NewContactController(dcContext: self.dcContext), animated: true)
                }
            }
            UIAction(title: String.localized("withdraw_qr_code"), image: UIImage(systemName: "trash"), attributes: [.destructive]) { [weak self] _ in
                self?.withdrawQrCode()
            }
        }
    )

    init(dcAccounts: DcAccounts) {
        self.dcAccounts = dcAccounts
        self.dcContext = dcAccounts.getSelected()
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = moreButton
        navigationItem.scrollEdgeAppearance = navigationController?.navigationBar.standardAppearance
        let host = UIHostingController(rootView: QrReadShowView(delegate: self, dcContext: dcContext))
        addChild(host)
        view.addSubview(host.view)
        host.didMove(toParent: self)
        host.view.fillSuperview()
        view.clipsToBounds = true
    }

    // MARK: - actions

    func share() {
        if let inviteLink = Utils.getInviteLink(context: dcContext, chatId: 0) {
            if let sourceItem = navigationItem.rightBarButtonItem {
                Utils.share(url: inviteLink, parentViewController: self, sourceItem: sourceItem)
            }
        }
    }

    func withdrawQrCode() {
        let alert = UIAlertController(title: String.localized("withdraw_verifycontact_explain"), message: nil, preferredStyle: .safeActionSheet)
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: String.localized("withdraw_qr_code"), style: .destructive, handler: { [weak self] _ in
            guard let self else { return }
            guard let code = dcContext.getSecurejoinQr(chatId: 0) else { return }
            _ = self.dcContext.setConfigFromQR(qrCode: code)
            navigationController?.popViewController(animated: true)
        }))
        present(alert, animated: true)
    }
}

// MARK: - QRCodeDelegate
extension QrPageController: QrCodeReaderDelegate {
    func handleQrCode(_ qrCode: String) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate, let navigationController else { return }
        navigationController.popToRootViewController(animated: false)
        appDelegate.appCoordinator.coordinate(qrCode: qrCode, from: navigationController)
    }
}

private struct QrReadShowView: View {
    weak var delegate: QrPageController?
    let dcContext: DcContext

    var body: some View {
        VStack(spacing: 0) {
            QrCodeReaderView(addHints: nil, showTroubleshooting: false, delegate: delegate)
            let hint = String.localized("qrshow_join_contact_hint", dcContext.displayname ?? .localized("unnamed"))
            QrView(dcContext: dcContext, qrCodeHint: hint).shadow(radius: 20)
        }.ignoresSafeArea()
    }
}
