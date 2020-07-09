import UIKit

class ThumbnailCache {

    static let shared = ThumbnailCache()
    private init() { }

    private lazy var cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.name = "thumbnail_cache"
        return cache
    }()

    func storeImage(image: UIImage, key: String){
        // cache.setObject(image, forKey: NSString(string: key))
    }

    func restoreImage(key: String) -> UIImage? {
        return nil
        //     return cache.object(forKey: NSString(string: key))
    }

    func clearCache() {
        cache.removeAllObjects()
    }
}
