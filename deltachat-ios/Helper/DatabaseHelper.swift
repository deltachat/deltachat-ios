import Foundation
class DatabaseHelper {

    /// The application group identifier defines a group of apps or extensions that have access to a shared container.
    /// The ID is created in the apple developer portal and can be changed there.
    static let applicationGroupIdentifier = "group.chat.delta.ios"

    var sharedDbFile: String {
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

    var localBlobsDir: String {
        return localDocumentsDir.appendingPathComponent("messenger.db-blobs").path
    }

    var localDocumentsDir: URL {
        let paths = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)
        return URL(fileURLWithPath: paths[0], isDirectory: true)
    }

    var currentDatabaseLocation: String {
        let filemanager = FileManager.default
        if filemanager.fileExists(atPath: localDbFile) {
            return localDbFile
        }
        return sharedDbFile
    }

    func clearSharedDbBlobsDir() {
        let fileManager = FileManager.default
        do {
            if fileManager.fileExists(atPath: sharedDbBlobsDir) {
                let filePaths =  try fileManager.contentsOfDirectory(atPath: sharedDbBlobsDir)
                for filePath in filePaths {
                    let completePath = URL(fileURLWithPath: sharedDbBlobsDir).appendingPathComponent(filePath)
                    try fileManager.removeItem(atPath: completePath.path)
                }
                try fileManager.removeItem(atPath: sharedDbBlobsDir)
            }
        } catch {
          logger.error("Could not clean shared blobs dir, it might be it didn't exist")
        }
    }

    func clearSharedDb() {
        let filemanager = FileManager.default
        if filemanager.fileExists(atPath: sharedDbFile) {
            do {
                try filemanager.removeItem(atPath: sharedDbFile)
            } catch {
                logger.error("Failed to delete db: \(error)")
            }
        }
    }

    func moveBlobsFolder() {
        let filemanager = FileManager.default
        if filemanager.fileExists(atPath: localBlobsDir) {
            do {
                clearSharedDbBlobsDir()
                try filemanager.moveItem(at: URL(fileURLWithPath: localBlobsDir), to: URL(fileURLWithPath: sharedDbBlobsDir))
            } catch let error {
                logger.error("Could not move db blobs directory to shared space: \(error.localizedDescription)")
            }
        }
    }

    func updateDatabaseLocation() -> String? {
      let filemanager = FileManager.default
      if filemanager.fileExists(atPath: localDbFile) {
          do {
              clearSharedDb()
              try filemanager.moveItem(at: URL(fileURLWithPath: localDbFile), to: URL(fileURLWithPath: sharedDbFile))
              moveBlobsFolder()
          } catch let error {
              logger.error("Could not update DB location. Share extension will probably not work. \n\(error.localizedDescription)")
              return localDbFile
          }
      }
      return sharedDbFile
    }

}
