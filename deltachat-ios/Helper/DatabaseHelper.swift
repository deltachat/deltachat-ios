import Foundation
class DatabaseHelper {

    var sharedDbFile: String {
        guard let fileContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.eu.merlinux.group.chat.delta.ios") else {
            return ""
        }
        let storeURL = fileContainer.appendingPathComponent("messenger.db")
        return storeURL.path
    }

    var localDbFile: String {
        return localDocumentsDir.appendingPathComponent("messenger.db").path
    }

    var sharedDbBlobsDir: String {
        guard let fileContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.eu.merlinux.group.chat.delta.ios") else {
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
            try? filemanager.removeItem(atPath: sharedDbFile)
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

    func testMove(toShared: Bool) -> String? {
        if toShared {
            return updateDatabaseLocation()
        } else {
            return reverse()
        }
    }

    func reverse() -> String? {
      let filemanager = FileManager.default
      if  filemanager.fileExists(atPath: sharedDbFile) {
          do {
              if filemanager.fileExists(atPath: localDbFile) {
                  logger.debug("remove local DB first, in order to move DB from shared to local space")
                  try? filemanager.removeItem(atPath: localDbFile)
              }
              try filemanager.moveItem(at: URL(fileURLWithPath: sharedDbFile), to: URL(fileURLWithPath: localDbFile))
              let filemanager = FileManager.default
              if filemanager.fileExists(atPath: sharedDbBlobsDir) {
                  if filemanager.fileExists(atPath: localBlobsDir) {
                      try? filemanager.removeItem(atPath: localBlobsDir)
                  }
                  do {
                  try filemanager.moveItem(at: URL(fileURLWithPath: sharedDbBlobsDir), to: URL(fileURLWithPath: localBlobsDir))
                  } catch let error {
                      logger.error("Could not move db blobs directory to shared space: \(error.localizedDescription)")
                  }
              }

          } catch let error {
              logger.error("Could not update DB location. Share extension will probably not work. \n\(error.localizedDescription)")
              return sharedDbFile
          }
      }
      return localDbFile
    }

}
