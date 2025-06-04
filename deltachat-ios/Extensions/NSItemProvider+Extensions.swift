import UniformTypeIdentifiers
import SDWebImage
import UIKit

extension NSItemProvider {
    // MARK: - Image
    
    public enum LoadImageError: Error {
        case failedToConvertGIFDataToImage
        case failedToConvertWebPDataToImage
        /// Should never be returned but in case loadObject returns nil for both image and error
        case loadObjectFailed
        case failedToConvertDataToImage
    }
    
    /// Wether loadImage is applicable to this provider
    public func canLoadImage(allowAnimated: Bool = true) -> Bool {
        (allowAnimated && hasItemConformingToTypeIdentifier(UTType.gif.identifier)) ||
        hasItemConformingToTypeIdentifier(UTType.webP.identifier) ||
        canLoadObject(ofClass: UIImage.self) ||
        hasItemConformingToTypeIdentifier(UTType.image.identifier)
    }
    
    /// Load any image including webP and gif
    /// Unlike native load functions this calls completion on the main thread
    @discardableResult
    public func loadImage(allowAnimated: Bool = true, completion: @escaping (UIImage?, Error?) -> Void) -> Progress {
        return if allowAnimated && hasItemConformingToTypeIdentifier(UTType.gif.identifier) {
            loadDataRepresentation(forTypeIdentifier: UTType.gif.identifier) { data, error in
                callCompletion(data.flatMap(SDAnimatedImage.init(data:)), error, or: .failedToConvertGIFDataToImage)
            }
        } else if hasItemConformingToTypeIdentifier(UTType.webP.identifier) {
            // If webP is provided and eg JPEG (or another type that is supported by loadObject),
            // always pick webP because it might have transparancy unlike JPEG.
            loadDataRepresentation(forTypeIdentifier: UTType.webP.identifier) { webPData, error in
                callCompletion(webPData.flatMap(UIImage.sd_image(withWebPData:)), error, or: .failedToConvertWebPDataToImage)
            }
        } else if canLoadObject(ofClass: UIImage.self) {
            loadObject(ofClass: UIImage.self) { imageItem, error in
                callCompletion(imageItem as? UIImage, error, or: .loadObjectFailed)
            }
        } else {
            // Some images (like webP) can't be loaded into UIImage by `loadObject` so we fall back on SD.
            // See `UIImage.readableTypeIdentifiersForItemProvider` for ones that can.
            loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                callCompletion(data.flatMap(UIImage.sd_image(with:)), error, or: .failedToConvertDataToImage)
            }
        }
        func callCompletion(_ image: UIImage?, _ error: Error?, or backupError: LoadImageError) {
            DispatchQueue.main.async {
                switch (image, error) {
                case (.none, .some): completion(nil, error)
                case (.some, .none): completion(image, nil)
                default: completion(nil, backupError)
                }
            }
        }
    }
    
    // MARK: - Video
    
    /// Wether loadCompressedVideo is applicable to this provider
    public func canLoadVideo() -> Bool {
        // Note: UTType.movie's doc implies that an mp4 file should have
        // both .mpeg4Movie and .movie but it does not on iOS 15
        hasItemConformingToTypeIdentifier(UTType.mpeg4Movie.identifier) ||
        hasItemConformingToTypeIdentifier(UTType.quickTimeMovie.identifier) ||
        hasItemConformingToTypeIdentifier(UTType.movie.identifier) ||
        hasItemConformingToTypeIdentifier(UTType.video.identifier)
    }
    
    /// Loads a video, converts it to mp4, and compresses the video.
    /// Unlike native load functions this calls completion on the main thread
    @discardableResult
    public func loadCompressedVideo(completion: @escaping (URL?, Error?) -> Void) -> Progress {
        var progressLater: Progress?
        let compress = { (url: URL?, _: Bool, error: Error?) in
            if let url {
                // Note: NSFileCoordinator is required on iOS 15
                NSFileCoordinator().coordinate(readingItemAt: url, error: nil) { url in
                    url.convertToMp4 { url, error in
                        progressLater?.completedUnitCount += 10
                        DispatchQueue.main.async { completion(url, error) }
                    }
                }
            } else {
                progressLater?.completedUnitCount += 10
                DispatchQueue.main.async { completion(url, error) }
            }
        }
        let progress = if hasItemConformingToTypeIdentifier(UTType.mpeg4Movie.identifier) {
            loadInPlaceFileRepresentation(forTypeIdentifier: UTType.mpeg4Movie.identifier, completionHandler: compress)
        } else if hasItemConformingToTypeIdentifier(UTType.quickTimeMovie.identifier) {
            loadInPlaceFileRepresentation(forTypeIdentifier: UTType.quickTimeMovie.identifier, completionHandler: compress)
        } else if hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            loadInPlaceFileRepresentation(forTypeIdentifier: UTType.movie.identifier, completionHandler: compress)
        } else {
            loadInPlaceFileRepresentation(forTypeIdentifier: UTType.video.identifier, completionHandler: compress)
        }
        progressLater = progress
        progress.totalUnitCount += 10
        return progress
    }
}
