import Foundation
import UIKit
import SafariServices
import Swifter
import DcCore

public class ShortcutManager {

    lazy var server: HttpServer = {
        let server = HttpServer()
        return server
    }()

    private let defaultPort: UInt16 = 8200
    private var localPort: UInt16 = 8200
    var dcContext: DcContext

    public init(dcContext: DcContext) {
        self.dcContext = dcContext
    }

    deinit {
        server.stop()
    }

    public lazy var shareIconBase64: String = {
        if #available(iOS 13.0, *) {
            return UIImage(systemName: "square.and.arrow.up")?.withTintColor(DcColors.primary).pngData()?.base64EncodedString() ?? ""
        } else {
            return ""
        }
    }()

    public lazy var addToHomeIconBase64: String = {
        if #available(iOS 13.0, *) {
            return UIImage(systemName: "plus.square")?.withTintColor(DcColors.defaultInverseColor).pngData()?.base64EncodedString() ?? ""
        } else {
            return ""
        }
    }()

    func showShortcutLandingPage(messageId: Int) {
        let message = dcContext.getMessage(id: messageId)
        if message.type != DC_MSG_WEBXDC {
            return
        }

        let deepLink = "chat.delta.deeplink://webxdc?accountId=\(dcContext.id)&chatId=\(message.chatId)&msgId=\(message.id)"
        guard let deepLinkUrl = URL(string: deepLink) else {
            return
        }

        let infoDict = message.getWebxdcInfoDict()
        let iconData = message.getWebxdcPreviewImage()?.jpegData(compressionQuality: 0) ?? UIImage(named: "appicon")?.pngData() ?? nil
        guard let name = infoDict["name"] as? String else {
            // TODO: use a default name?!
            return
        }

        let iconBase64 = iconData?.base64EncodedString() ?? ""
        let html = htmlFor(title: name,
                           urlToRedirect: deepLinkUrl,
                           iconBase64: iconBase64)
        guard let base64 = html.data(using: .utf8)?.base64EncodedString() else {
            return
        }
        server["/s"] = { _ in
            return .movedPermanently("data:text/html;base64,\(base64)")
        }

        var attempts = 0
        var tryToReconnect = true
        while tryToReconnect && attempts < 5 {
            do {
                localPort = defaultPort + UInt16(Int.random(in: 1...100))
                try server.start(localPort)
                tryToReconnect = false
            } catch SocketError.bindFailed(let errorString) {
                attempts += 1
                tryToReconnect = true
                logger.error(errorString)
            } catch {
                tryToReconnect = false
                logger.error(error)
            }
        }

        guard let shortcutUrl = URL(string: "http://localhost:\(localPort)/s") else {
            return
        }

        UIApplication.shared.open(shortcutUrl)
    }

    /**
     TODO: evaluate if we really want to have a startup page, if se it seems we have to generate them for all possible device resolutions:
     https://stackoverflow.com/questions/4687698/multiple-apple-touch-startup-image-resolutions-for-ios-web-app-esp-for-ipad
     <link rel="apple-touch-startup-image" media="(orientation: landscape)" href="data:image/jpeg;base64,\(lSplashBase64)"/>
     <link rel="apple-touch-startup-image" media="(orientation: portrait)" href="data:image/jpeg;base64,\(pSplashBase64)"/>
     */
    private func htmlFor(title: String, urlToRedirect: URL, iconBase64: String) -> String {
        return """
        <html>
        <head>
        <title>\(title)</title>
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
        <meta name="apple-mobile-web-app-capable" content="yes">
        <meta name="apple-mobile-web-app-status-bar-style" content="#ffffff">
        <meta name="apple-mobile-web-app-title" content="\(title)">
        <link rel="apple-touch-icon-precomposed" href="data:image/jpeg;base64,\(iconBase64)"/>
        </head>
        <body>
        <a id="redirect" href="\(urlToRedirect.absoluteString)"></a>
        </body>
        </html>
        <style>
            h1, h2 {
                text-align: center;
            }
            .appContainer {
              padding-top: 0px;
              text-align: center;
              display: flex;
              justify-content: center;
              align-items: center;
            }
            div {
                padding: 1rem 1rem 1rem 1rem;
            }
            body {
                font-size: 16pt;
                font-family: -apple-system, sans-serif;
                -webkit-text-size-adjust: none;
            }
            .previewImage {
                height: 60px;
                width: 60px;
                border-radius: 8px;
                padding: .5rem .5rem .5rem .5rem;
            }
            .iconImage {
                height: 20px;
                width: 20px;
                padding: 0 .5rem 0 .5rem;
            }

            @media (prefers-color-scheme: dark) {
              body {
                background-color: black !important;
                color: #eee;
              }
            }
         </style>
         <script type="text/javascript">

            if (window.navigator.standalone) {
                var element = document.getElementById('redirect');
                var event = document.createEvent('MouseEvents');
                event.initEvent('click', true, true, document.defaultView, 1, 0, 0, 0, 0, false, false, false, false, 0, null);
                document.body.style.backgroundColor = '#FFFFFF';
                setTimeout(function() { element.dispatchEvent(event); }, 25);
            } else {
                 var div = document.createElement('div');
                 var header = document.createElement('h2');
                 header.append('\(String.localized("add_to_home"))');
                 div.appendChild(header);
                 document.body.appendChild(div);

                 var appContainer = document.createElement('div');
                 appContainer.classList.add("appContainer");
                 var img = document.createElement('img');
                 img.src = "data:image/png;base64,\(iconBase64)";
                 img.classList.add("previewImage");
                 appContainer.appendChild(img);
                 var header = document.createElement('h1');
                 header.append('\(title)');
                 appContainer.appendChild(header);
                 document.body.appendChild(appContainer);

                 var div = document.createElement('div');
                 div.appendChild(document.createTextNode('1. '));
                 var img = document.createElement('img');
                 img.src = "data:image/png;base64,\(shareIconBase64)";
                 img.classList.add("iconImage");
                 div.appendChild(img);
                 var node = document.createTextNode("\(String.localized("shortcut_share_btn"))");
                 div.appendChild(node);
                 document.body.appendChild(div);

                 var div = document.createElement('div');
                 div.appendChild(document.createTextNode('2. '));
                 var img = document.createElement('img');
                 img.src = "data:image/png;base64,\(addToHomeIconBase64)";
                 img.classList.add("iconImage");
                 div.appendChild(img);
                 var node = document.createTextNode("\(String.localized("shortcut_add_to_home_description"))");
                 div.appendChild(node);

                 document.body.appendChild(div);
            }
        </script>
        """

    }
}