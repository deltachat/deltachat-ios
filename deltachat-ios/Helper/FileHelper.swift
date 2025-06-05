import Foundation

public class FileHelper {
    
    // implementation is following Apple's recommendations
    // https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/AccessingFilesandDirectories/AccessingFilesandDirectories.html
    public static func saveData(data: Data, name: String? = nil, suffix: String? = nil, directory: FileManager.SearchPathDirectory = .applicationSupportDirectory) -> String? {
        var path: URL?

        // ensure directory exists (application support dir doesn't exist per default)
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: directory, in: .userDomainMask) as [URL]
        guard let identifier = Bundle.main.bundleIdentifier else {
            print("err: Could not find bundle identifier")
            return nil
        }
        guard let directoryURL = urls.first else {
            print("err: Could not find directory url for \(String(describing: directory)) in .userDomainMask")
            return nil
        }
        var subdirectoryURL = directoryURL.appendingPathComponent(identifier)
        do {
            if !fileManager.fileExists(atPath: subdirectoryURL.path) {
                try fileManager.createDirectory(at: subdirectoryURL, withIntermediateDirectories: true, attributes: nil)
            }
        } catch {
            print("err: \(error.localizedDescription)")
            return nil
        }

        // Opt out from iCloud backup
        var resourceValues: URLResourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        do {
            try subdirectoryURL.setResourceValues(resourceValues)
        } catch {
            print("err: \(error.localizedDescription)")
            return nil
        }

        // add file name to path
        if let name {
            if let suffix {
                path = subdirectoryURL.appendingPathComponent("\(name).\(suffix)")
            } else {
                path = subdirectoryURL.appendingPathComponent(name)
            }
        } else if let suffix {
            let timestamp = Double(Date().timeIntervalSince1970)
            path = subdirectoryURL.appendingPathComponent("\(timestamp).\(suffix)")
        }
        guard let path else { return nil }

        // write data
        do {
            try data.write(to: path)
            return path.relativePath
        } catch {
            print("err: \(error.localizedDescription)")
            return nil
        }
    }

    public static func deleteFileAsync(atPath: String?) {
        if Thread.isMainThread {
            DispatchQueue.global().async {
                deleteFile(atPath)
            }
        } else {
            deleteFile(atPath)
        }
    }

    public static func deleteFile(_ atPath: String?) {
        guard let atPath = atPath else {
            return
        }

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: atPath) {
            return
        }

        do {
            try fileManager.removeItem(atPath: atPath)
        } catch {
            print("err: \(error.localizedDescription)")
        }
    }

    static func copyIfPossible(src: URL, dest: URL) -> URL {
        guard src != dest else { return src }
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: src, to: dest)
            return dest
        } catch {
            logger.error("cannot copy \(src) to \(dest)")
            return src
        }
    }
}
