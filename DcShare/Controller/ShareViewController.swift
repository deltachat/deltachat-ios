import UIKit
import Social
import DcCore
import MobileCoreServices
import Intents
import SDWebImageWebPCoder
import SDWebImage

let logger = getDcLogger()

class ShareViewController: UIViewController {
    var task: Task<Void, Never>?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Clear previously sharedItems
        try? FileManager.default.removeItem(at: shareExtensionDirectory)
        try? FileManager.default.createDirectory(at: shareExtensionDirectory, withIntermediateDirectories: true)
        task = Task {
            do {
                // Save the files in a container the main app can access
                let inputItems = extensionContext?.inputItems as? [NSExtensionItem] ?? []
                let attachments = try await inputItems
                    .flatMap { $0.attachments ?? [] }
                    .asyncMap { try await CodableNSItemProvider.init(from: $0) }
            
                // Create deeplink referencing shared items
                if let jsonData = try? JSONEncoder().encode(attachments),
                   let json = String(data: jsonData, encoding: .utf8),
                   let jsonUrlEncoded = json.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                   var url = URL(string: "chat.delta.deeplink://share?data=\(jsonUrlEncoded)") {
                    
                    // Add direct share parameters to deeplink
                    if let intent = extensionContext?.intent as? INSendMessageIntent,
                       let identifiers = intent.conversationIdentifier?.split(separator: "."),
                       identifiers.count == 2 {
                        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                        components?.queryItems?.append(contentsOf: [
                            .init(name: "accountId", value: String(identifiers[0])),
                            .init(name: "chatId", value: String(identifiers[1])),
                        ])
                        url = components?.url ?? url
                    }
                    
                    // Open main app
                    var responder: UIResponder? = self
                    while responder != nil {
                        if let application = responder as? UIApplication {
                            await application.open(url)
                            break
                        }
                        responder = responder?.next
                    }
                    
                    // Fallback
                    if responder == nil {
                        return logAndAlert(error: ShareError.couldNotOpenMainApp)
                    }
                }
            } catch {
                return logAndAlert(error: error)
            }
            
            // Complete
            extensionContext?.completeRequest(returningItems: [])
        }
    }
    
    func logAndAlert(error: any Error) {
        logger.error(error.localizedDescription)
        let alert = UIAlertController(title: nil, message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default) { [weak self] _ in
            self?.extensionContext!.cancelRequest(withError: error)
        })
        present(alert, animated: true)
    }
}

enum ShareError: Error, LocalizedError {
    case couldNotOpenMainApp
    
    var errorDescription: String? {
        switch self {
        case .couldNotOpenMainApp: "Failed to open Delta Chat from share extension"
        }
    }
}

extension Sequence {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var values = [T]()

        for element in self {
            try await values.append(transform(element))
        }

        return values
    }
}
