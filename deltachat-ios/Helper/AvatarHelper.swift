import Foundation
import UIKit

class AvatarHelper {

    static let selfAvatarFile = "contact_avatar_self.jpg"
    private static let avatarPath = "avatars"

    static func saveSelfAvatarImage(image: UIImage) {
        if let data = image.jpegData(compressionQuality: 1.0) {
            let filemanager = FileManager.default
            let docDir = filemanager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let avatarDir = docDir.appendingPathComponent(avatarPath)
            let avatarFile = avatarDir.appendingPathComponent(selfAvatarFile)
            do {
                try filemanager.createDirectory(atPath: avatarDir.path,
                                                withIntermediateDirectories: false)
            } catch let error as NSError {
                logger.info("directory not created: \(error.localizedDescription)")
            }

            if !filemanager.changeCurrentDirectoryPath(avatarDir.path) {
                logger.warning("Could not change into avatar directory")
                return
            }

            if filemanager.fileExists(atPath: avatarFile.path) {
                do {
                    try filemanager.removeItem(atPath: avatarFile.path)
                } catch let error {
                    logger.warning("Error: \(error.localizedDescription)")
                }
            }

            do {
                try data.write(to: avatarFile)
            } catch let error {
                logger.warning("Error: \(error.localizedDescription)")
                return
            }

            DcConfig.selfavatar = avatarFile.path
        }
    }
}
