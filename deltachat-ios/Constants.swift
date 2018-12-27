//
//  Constants.swift
//  deltachat-ios
//
//  Created by Bastian van de Wetering on 08.11.17.
//  Copyright © 2017 Jonas Reinsch. All rights reserved.
//

import UIKit

struct Constants {
    // see: https://core.telegram.org/blackberry/chat
    static let chatColors:[UIColor] = ["#ee4928", "#41a903", "#e09602", "#0f94ed", "#8f3bf7", "#fc4380", "#00a1c4", "#eb7002"].map {s in UIColor(hexString: s)}
     struct Color {
        static let bubble = UIColor(netHex: 0xefffde)
    }
    
    struct Keys {
        static let deltachatUserProvidedCredentialsKey = "__DELTACHAT_USER_PROVIDED_CREDENTIALS_KEY__"
        static let deltachatImapEmailKey = "__DELTACHAT_IMAP_EMAIL_KEY__"
        static let deltachatImapPasswordKey = "__DELTACHAT_IMAP_PASSWORD_KEY__"
    }
    
    static let primaryColor = UIColor(red: 81/255, green: 73/255, blue: 255/255, alpha: 1)
    static let messagePrimaryColor = UIColor(red: 234/255, green: 233/255, blue: 246/255, alpha: 1)
    static let messageSecondaryColor = UIColor(red: 245/255, green: 245/255, blue: 245/255, alpha: 1)
    
    static let defaultShadow = UIImage(color: UIColor(hexString: "ff2b82"), size: CGSize(width: 1, height: 1))
    static let onlineShadow = UIImage(color: UIColor(hexString: "3ed67e"), size: CGSize(width: 1, height: 1))
}

