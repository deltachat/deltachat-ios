import Foundation
import UIKit
import SafariServices
import Swifter
import DcCore
import SDWebImage

public class ShortcutManager {

    lazy var server: HttpServer = {
        let server = HttpServer()
        return server
    }()

    private let defaultPort: UInt16 = 8200
    private var localPort: UInt16 = 8200
    private let dcContext: DcContext
    private let messageId: Int

    public init(dcContext: DcContext, messageId: Int) {
        self.dcContext = dcContext
        self.messageId = messageId
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

    private lazy var scaledDownLogo: UIImage? = {
        let msg = dcContext.getMessage(id: messageId)
        return msg.getWebxdcPreviewImage()?
            .scaleDownImage(toMax: 160)?
            .sd_roundedCornerImage(withRadius: 12,
                                   corners: SDRectCorner.allCorners,
                                   borderWidth: 0,
                                   borderColor: nil)
    }()

    public lazy var landscapeSplashBase64: String = {
        let image = scaledDownLogo?
            .generateSplash(backgroundColor: DcColors.chatBackgroundColor, isPortrait: false)?
            .pngData()?
            .base64EncodedString() ?? ""
        return image
    }()

    public lazy var portraitSplashBase64: String = {
        let image = scaledDownLogo?
            .generateSplash(backgroundColor: DcColors.chatBackgroundColor, isPortrait: true)?
            .pngData()?
            .base64EncodedString() ?? ""
        return image
    }()

    func showShortcutLandingPage() {
        let message = dcContext.getMessage(id: messageId)
        if message.type != DC_MSG_WEBXDC {
            return
        }

        let deepLink = "chat.delta.deeplink://webxdc?accountId=\(dcContext.id)&chatId=\(message.chatId)&msgId=\(message.id)"
        guard let deepLinkUrl = URL(string: deepLink) else {
            return
        }

        let infoDict = message.getWebxdcInfoDict()
        let iconData = scaledDownLogo?.pngData() ?? UIImage(named: "appicon")?.pngData() ?? nil
        let document = infoDict["document"] as? String ?? ""
        let webxdcName = infoDict["name"] as? String ?? "ErrName" // name should not be empty
        let iconTitle = document.isEmpty ? webxdcName : document

        let iconBase64 = iconData?.base64EncodedString() ?? ""
        let html = htmlFor(title: iconTitle,
                           urlToRedirect: deepLinkUrl,
                           iconBase64: iconBase64)
        guard let base64 = html.data(using: .utf8)?.base64EncodedString() else {
            return
        }
        server["/s"] = { _ in
            var headers = ["Location": "data:text/html;base64,\(base64)"]
            headers["Cache-Control"] = "no-store"
            return .raw(301, "Moved Permanently", headers, nil)
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
                logger.error("\(String(describing: error))")
            }
        }

        guard let shortcutUrl = URL(string: "http://localhost:\(localPort)/s") else {
            return
        }

        UIApplication.shared.open(shortcutUrl)
    }

    private func htmlFor(title: String, urlToRedirect: URL, iconBase64: String) -> String {
        return """
        <html>
        <head>
        <title>\(title)</title>
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
        <meta name="apple-mobile-web-app-capable" content="yes">
        <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
        <meta name="apple-mobile-web-app-title" content="\(title)">
        <link rel="apple-touch-startup-image" media="(orientation: landscape)" href="data:image/jpeg;base64,\(landscapeSplashBase64)"/>
        <link rel="apple-touch-startup-image" media="(orientation: portrait)" href="data:image/jpeg;base64,\(portraitSplashBase64)"/>
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
              display: block;
              justify-content: center;
              align-items: center;
            }
            .screenshotWrapper {
              padding-top: 0px;
              display: flex;
              justify-content: center;
              align-items: center;
              width: 100vw;
              height: 100vh;
              position: relative;
            }
            .screenshotImage {
              width: 160px;
              height: 160px;
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
                height: 90px;
                width: 90px;
                padding: .5rem .5rem .5rem .5rem;
            }
            .webxdcName {
                text-align: center;
                font-size: 19pt;
                font-family: -apple-system, sans-serif;
                -webkit-text-size-adjust: none;
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
                var appContainer = document.createElement('div');
                appContainer.classList.add("screenshotWrapper");
                var img = document.createElement('img');
                img.src = "data:image/png;base64,\(iconBase64)";
                img.classList.add("screenshotImage");
                appContainer.appendChild(img);
                document.body.appendChild(appContainer);

                var element = document.getElementById('redirect');
                var event = document.createEvent('MouseEvents');
                event.initEvent('click', true, true, document.defaultView, 1, 0, 0, 0, 0, false, false, false, false, 0, null);
                setTimeout(function() { element.dispatchEvent(event); }, 25);
            } else {
                 var div = document.createElement('div');
                 var header = document.createElement('h2');
                 header.append('\(String.localized("add_to_home_screen"))');
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
                 header.classList.add("webxdcName");
                 appContainer.appendChild(header);
                 document.body.appendChild(appContainer);

                 var div = document.createElement('div');
                 div.appendChild(document.createTextNode('1. '));
                 var img = document.createElement('img');
                 img.src = "data:image/png;base64,\(shareIconBase64)";
                 img.classList.add("iconImage");
                 div.appendChild(img);
                 var node = document.createTextNode("\(String.localized("shortcut_step1_tap_share_btn").replacingOccurrences(of: "\"", with: " - "))");
                 div.appendChild(node);
                 document.body.appendChild(div);

                 var div = document.createElement('div');
                 div.appendChild(document.createTextNode('2. '));
                 var img = document.createElement('img');
                 img.src = "data:image/png;base64,\(addToHomeIconBase64)";
                 img.classList.add("iconImage");
                 div.appendChild(img);
                 var node = document.createTextNode("\(String.localized("shortcut_step2_tap_add_to_home_screen").replacingOccurrences(of: "\"", with: " - "))");
                 div.appendChild(node);

                 document.body.appendChild(div);
            }
        </script>
        """

    }
}
