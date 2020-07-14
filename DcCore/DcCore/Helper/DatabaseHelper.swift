import Foundation
public class DatabaseHelper {

    /// The application group identifier defines a group of apps or extensions that have access to a shared container.
    /// The ID is created in the apple developer portal and can be changed there.
    static let applicationGroupIdentifier = "group.chat.delta.ios"

    public var sharedDir: URL? {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: DatabaseHelper.applicationGroupIdentifier)
    }

    public var sharedDbFile: String {
        guard let fileContainer = sharedDir else {
            return ""
        }
        let storeURL = fileContainer.appendingPathComponent("messenger.db")
        return storeURL.path
    }

    var localDbFile: String {
        return localDocumentsDir.appendingPathComponent("messenger.db").path
    }

    var sharedDbBlobsDir: String {
        guard let fileContainer = sharedDir else {
            return ""
        }
        return fileContainer.appendingPathComponent("messenger.db-blobs").path
    }

    var localDbBlobsDir: String {
        return localDocumentsDir.appendingPathComponent("messenger.db-blobs").path
    }

    var localDocumentsDir: URL {
        let paths = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)
        return URL(fileURLWithPath: paths[0], isDirectory: true)
    }

    public var currentDatabaseLocation: String {
        let filemanager = FileManager.default
        if filemanager.fileExists(atPath: localDbFile) {
            return localDbFile
        }
        return sharedDbFile
    }

    var currentBlobsDirLocation: String {
        let filemanager = FileManager.default
        if filemanager.fileExists(atPath: localDbBlobsDir) {
            return localDbBlobsDir
        }
        return sharedDbBlobsDir
    }

    public init() {

    }

    func clearDbBlobsDir(at path: String) {
        let fileManager = FileManager.default
        do {
            if fileManager.fileExists(atPath: path) {
                let filePaths =  try fileManager.contentsOfDirectory(atPath: path)
                for filePath in filePaths {
                    let completePath = URL(fileURLWithPath: path).appendingPathComponent(filePath)
                    try fileManager.removeItem(atPath: completePath.path)
                }
                try fileManager.removeItem(atPath: path)
            }
        } catch {
            DcContext.shared.logger?.error("Could not clean shared blobs dir, it might be it didn't exist")
        }
    }

    func clearDb(at path: String) {
        let filemanager = FileManager.default
        if filemanager.fileExists(atPath: path) {
            do {
                try filemanager.removeItem(atPath: path)
            } catch {
                DcContext.shared.logger?.error("Failed to delete db: \(error)")
            }
        }
    }

    public func clearAccountData() {
        clearDb(at: currentDatabaseLocation)
        clearDbBlobsDir(at: currentBlobsDirLocation)
    }

    func moveBlobsFolder() {
        let filemanager = FileManager.default
        if filemanager.fileExists(atPath: localDbBlobsDir) {
            do {
                clearDbBlobsDir(at: sharedDbBlobsDir)
                try filemanager.moveItem(at: URL(fileURLWithPath: localDbBlobsDir), to: URL(fileURLWithPath: sharedDbBlobsDir))
            } catch let error {
                DcContext.shared.logger?.error("Could not move db blobs directory to shared space: \(error.localizedDescription)")
            }
        }
    }

    public func updateDatabaseLocation() -> String? {
      let filemanager = FileManager.default
      if filemanager.fileExists(atPath: localDbFile) {
          do {
              clearDb(at: sharedDbFile)
              try filemanager.moveItem(at: URL(fileURLWithPath: localDbFile), to: URL(fileURLWithPath: sharedDbFile))
              moveBlobsFolder()
          } catch let error {
              DcContext.shared.logger?.error("Could not update DB location. Share extension will probably not work. \n\(error.localizedDescription)")
              return localDbFile
          }
      }
      return sharedDbFile
    }

    public func updateSucceeded() -> Bool {
        return !FileManager.default.fileExists(atPath: localDbFile)
    }
}
