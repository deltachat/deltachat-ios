import Foundation


class AvatarHelper {

    static let groupTemplate = "group_chat_avatar_%s_.jpg"
    static let contactTemplate = "contact_avatar_%s.jpg"
    static let selfAvatarFile = "contact_avatar_self.jpg"
    private static let avatarPath = "avatars"

    // blocking method (reads/writes to storage)
    static func setSelfAvatarFile(fileUrl: URL) {
        let filemanager = FileManager.default
        let docDir = filemanager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let avatarDir = docDir.appendingPathComponent(avatarPath)
        let avatarFile = avatarDir.appendingPathComponent(selfAvatarFile)
        do {
            try filemanager.createDirectory(atPath: avatarDir.path,
                                            withIntermediateDirectories: false)
        } catch let error as NSError {
            logger.warning("Could not create avatar directory: \(error.localizedDescription)")
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
            try filemanager.copyItem(at: fileUrl, to: avatarFile)
        } catch let error {
            logger.warning("Error: \(error.localizedDescription)")
            return
        }

        DcConfig.selfavatar = avatarFile.path

    }

}
