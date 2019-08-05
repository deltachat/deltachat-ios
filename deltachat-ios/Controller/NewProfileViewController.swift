//
//  NewProfileViewController.swift
//  deltachat-ios
//

import Foundation
import UIKit


class NewProfileViewController: UIViewController {
	weak var coordinator: ProfileCoordinator?

	var contact: DCContact? {
		// This is nil if we do not have an account setup yet
		if !DCConfig.configured {
			return nil
		}
		return DCContact(id: Int(DC_CONTACT_ID_SELF))
	}
	
	var fingerprint: String? {
		if !DCConfig.configured {
			return nil
		}
		
		if let cString = dc_get_securejoin_qr(mailboxPointer, 0) {
			return String(cString: cString)
		}
		
		return nil
	}

	override func loadView() {
		let view = UIView()
		view.backgroundColor = UIColor.white
		self.view = view
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		title = String.localized("my_profile")
		self.edgesForExtendedLayout = []

		let contactCell = createContactCell()
		let qrCode = createQRCodeView()
		let qrCodeScanner = createQRCodeScannerButton()
	
		self.view.addSubview(contactCell)
		self.view.addSubview(qrCode)
		self.view.addSubview(qrCodeScanner)

		self.view.addConstraint(contactCell.constraintAlignTopTo(self.view))
		self.view.addConstraint(contactCell.constraintAlignLeadingTo(self.view))
		self.view.addConstraint(contactCell.constraintAlignTrailingTo(self.view))
		self.view.addConstraint(qrCode.constraintCenterYTo(self.view))
		self.view.addConstraint(qrCode.constraintCenterXTo(self.view))
		self.view.addConstraint(qrCodeScanner.constraintToBottomOf(qrCode, paddingTop: 25))
		self.view.addConstraint(qrCodeScanner.constraintCenterXTo(self.view))
	}
	
	private func createQRCodeScannerButton() -> UIView {
		let btn = UIButton.init(type: UIButton.ButtonType.system)
		btn.translatesAutoresizingMaskIntoConstraints = false
		btn.setTitle(String.localized("qrscan_title"), for: .normal)
		btn.addTarget(self, action:#selector(self.openQRCodeScanner), for: .touchUpInside)
		return btn
	}

	@objc func openQRCodeScanner() {
		let qrCodeReaderController = QrCodeReaderController()
		if let ctrl = navigationController {
			ctrl.pushViewController(qrCodeReaderController, animated: true)
		}
	}
	
	private func createQRCodeView() -> UIView {
		if let fingerprint = self.fingerprint {
			let width: CGFloat = 130
			
			let frame = CGRect(origin: .zero, size: .init(width: width, height: width))
			let imageView = QRCodeView(frame: frame)
			imageView.generateCode(
				fingerprint,
				foregroundColor: .darkText,
				backgroundColor: .white
			)
			imageView.translatesAutoresizingMaskIntoConstraints = false
			imageView.widthAnchor.constraint(equalToConstant: width).isActive = true
			imageView.heightAnchor.constraint(equalToConstant: width).isActive = true
			imageView.translatesAutoresizingMaskIntoConstraints = false
			return imageView
		}
		return UIImageView()
	}
	
	private func createContactCell() -> UIView {
		let bg = UIColor(red: 248 / 255, green: 248 / 255, blue: 255 / 255, alpha: 1.0)
		
		let profileView = ProfileView(frame: CGRect())
		if let contact = self.contact {
			let name = DCConfig.displayname ?? contact.name
			profileView.setBackgroundColor(bg)
			profileView.nameLabel.text = name
			profileView.emailLabel.text = contact.email
			profileView.darkMode = false
			if let img = contact.profileImage {
				profileView.setImage(img)
			} else {
				profileView.setBackupImage(name: name, color: contact.color)
			}
			profileView.setVerified(isVerified: contact.isVerified)
		} else {
			profileView.nameLabel.text = String.localized("no_account_setup")
		}
		
		return profileView
	}
	
	override func viewWillAppear(_: Bool) {
		navigationController?.navigationBar.prefersLargeTitles = true
	}
	
	func displayNewChat(contactId: Int) {
		let chatId = dc_create_chat_by_contact_id(mailboxPointer, UInt32(contactId))
		let chatVC = ChatViewController(chatId: Int(chatId))
		
		chatVC.hidesBottomBarWhenPushed = true
		navigationController?.pushViewController(chatVC, animated: true)
	}
	
	
}

