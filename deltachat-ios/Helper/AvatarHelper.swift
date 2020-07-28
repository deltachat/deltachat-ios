import Foundation
import UIKit
import DcCore

class AvatarHelper {
    static let tmpFile = "tempAvatar.jpg"
    private static let avatarPath = "avatars"

    enum FileError: Error {
        case runtimeError(String)
    }

    static func saveSelfAvatarImage(dcContext: DcContext, image: UIImage) {
        do {
            let avatarFile = try saveAvatarImageToFile(image: image)
            dcContext.selfavatar = avatarFile.path
            deleteAvatarFile(avatarFile)
        } catch let error {
            logger.error("Error saving Image: \(error.localizedDescription)")
        }
    }

    static func saveChatAvatar(dcContext: DcContext, image: UIImage?, for chatId: Int) {
        do {
            if let image = image {
                let groupFileName = try saveAvatarImageToFile(image: image)
                dcContext.setChatProfileImage(chatId: chatId, path: groupFileName.path)
                deleteAvatarFile(groupFileName)
            } else {
                dcContext.setChatProfileImage(chatId: chatId, path: nil)
            }
        } catch let error {
            logger.error("Error saving Image: \(error.localizedDescription)")
        }
    }

    private static func saveAvatarImageToFile(image: UIImage) throws -> URL {
        if let data = image.jpegData(compressionQuality: 1.0) {
            let filemanager = FileManager.default
            let docDir = filemanager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let avatarDir = docDir.appendingPathComponent(avatarPath)
            let avatarFile = avatarDir.appendingPathComponent(tmpFile)

            if !filemanager.fileExists(atPath: avatarDir.path) {
                try filemanager.createDirectory(atPath: avatarDir.path, withIntermediateDirectories: false)
            }

            if !filemanager.changeCurrentDirectoryPath(avatarDir.path) {
                throw FileError.runtimeError("Could not change to Avatar directory")
            }
            
            try data.write(to: avatarFile)
            return avatarFile
        } else {
            throw FileError.runtimeError("Could not convert UIImage to jpegData")
        }
    }

    private static func deleteAvatarFile(_ url: URL) {
        let filemanager = FileManager.default
        if filemanager.fileExists(atPath: url.path) {
            do {
                try filemanager.removeItem(atPath: url.path)
            } catch let error {
                logger.warning("Error: \(error.localizedDescription)")
            }
        }
    }

}
