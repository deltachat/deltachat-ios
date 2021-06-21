import Foundation
public class DatabaseHelper {

    /// The application group identifier defines a group of apps or extensions that have access to a shared container.
    /// The ID is created in the apple developer portal and can be changed there.
    static let applicationGroupIdentifier = "group.chat.delta.ios"

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

    var sharedDbBlobsDir: String {
        guard let fileContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: DatabaseHelper.applicationGroupIdentifier) else {
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

    public var unmanagedDatabaseLocation: String? {
        let filemanager = FileManager.default
        if filemanager.fileExists(atPath: localDbFile) {
            return localDbFile
        } else if filemanager.fileExists(atPath: sharedDbFile) {
            return sharedDbFile
        }
        return nil
    }

    var unmanagedBlobsDirLocation: String? {
        let filemanager = FileManager.default
        if filemanager.fileExists(atPath: localDbBlobsDir) {
            return localDbBlobsDir
        } else if filemanager.fileExists(atPath: sharedDbBlobsDir) {
            return sharedDbBlobsDir
        }
        return nil
    }

    var dcLogger: Logger?

    public init(dcLogger: Logger?) {
        self.dcLogger = dcLogger
    }

    func clearDbBlobsDir(at path: String?) {
        guard let path = path else { return }
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
            dcLogger?.error("Could not clean shared blobs dir, it might be it didn't exist")
        }
    }

    func clearDb(at path: String?) {
        guard let path = path else { return }
        let filemanager = FileManager.default
        if filemanager.fileExists(atPath: path) {
            do {
                try filemanager.removeItem(atPath: path)
            } catch {
                dcLogger?.error("Failed to delete db: \(error)")
            }
        }
    }

    public func clearUnmanagedAccountData() {
        clearDb(at: unmanagedDatabaseLocation)
        clearDbBlobsDir(at: unmanagedBlobsDirLocation)
    }

    func moveBlobsFolder() {
        let filemanager = FileManager.default
        if filemanager.fileExists(atPath: localDbBlobsDir) {
            do {
                clearDbBlobsDir(at: sharedDbBlobsDir)
                try filemanager.moveItem(at: URL(fileURLWithPath: localDbBlobsDir), to: URL(fileURLWithPath: sharedDbBlobsDir))
            } catch let error {
                dcLogger?.error("Could not move db blobs directory to shared space: \(error.localizedDescription)")
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
              dcLogger?.error("Could not update DB location. Share extension will probably not work. \n\(error.localizedDescription)")
              return localDbFile
          }
      }
      return sharedDbFile
    }

}
