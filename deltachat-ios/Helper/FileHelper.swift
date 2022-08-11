import Foundation

public class FileHelper {
    
    // implementation is following Apple's recommendations
    // https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/AccessingFilesandDirectories/AccessingFilesandDirectories.html
    public static func saveData(data: Data, name: String? = nil, suffix: String, directory: FileManager.SearchPathDirectory = .applicationSupportDirectory) -> String? {
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
        if let name = name {
            path = subdirectoryURL.appendingPathComponent("\(name).\(suffix)")
        } else {
            let timestamp = Double(Date().timeIntervalSince1970)
            path = subdirectoryURL.appendingPathComponent("\(timestamp).\(suffix)")
        }
        guard let path = path else { return nil }

        // write data
        do {
            try data.write(to: path)
            return path.relativePath
        } catch {
            print("err: \(error.localizedDescription)")
            return nil
        }
    }
}
