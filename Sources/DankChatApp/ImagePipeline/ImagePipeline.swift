import SDWebImage
import SDWebImageWebPCoder

enum ImagePipeline {
    private static let configureOnce: Void = {
        let webPCoder = SDImageWebPCoder.shared
        SDImageCodersManager.shared.addCoder(webPCoder)

        let cacheConfig = SDImageCache.shared.config
        cacheConfig.maxDiskSize = 300 * 1024 * 1024
        cacheConfig.maxMemoryCost = 100 * 1024 * 1024
    }()

    static func configure() {
        _ = configureOnce
    }
}
