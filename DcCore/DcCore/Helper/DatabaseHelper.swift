import Foundation
public class DatabaseHelper {

    /// The application group identifier defines a group of apps or extensions that have access to a shared container.
    /// The ID is created in the apple developer portal and can be changed there.
    static let applicationGroupIdentifier = "group.chat.delta.ios"

    public init() {}

    public var sharedDbFile: String {
        guard let fileContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: DatabaseHelper.applicationGroupIdentifier) else {
            return ""
        }
        let storeURL = fileContainer.appendingPathComponent("messenger.db")
        return storeURL.path
    }

    var localDbFile: String {
        return localDocumentsDir.appendingPathComponent("messenger.db").path
    }

    var localDocumentsDir: URL {
        let paths = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)
        return URL(fileURLWithPath: paths[0], isDirectory: true)
    }

    public var unmanagedDatabaseLocation: String? {
        let filemanager = FileManager.default
        if filemanager.fileExists(atPath: localDbFile) {
            return localDbFile
        } else if filemanager.fileExists(atPath: sharedDbFile) {
            return sharedDbFile
        }
        return nil
    }
}
