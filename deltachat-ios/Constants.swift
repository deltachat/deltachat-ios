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
}

