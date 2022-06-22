import Foundation
import UIKit
import WebKit

public class WebView: WKWebView {
    
    weak var searchAccessoryBar: InputBarAccessoryView?
    
    public override var inputAccessoryView: UIView? {
        logger.debug("return searchAccessoryBar")
        return searchAccessoryBar
    }
    
    public override var canBecomeFirstResponder: Bool {
        logger.debug("I can become a first responder!")
        return true
    }
        
}
