import SwiftUI
import Foundation

/// 画像をキャッシュして管理するクラス
final class ImageCache {
    static let shared = ImageCache()
    
    private let memoryCache = NSCache<NSString, UIImage>()
    private let diskCacheURL: URL?
    private let fileManager = FileManager.default
    
    private init() {
        // メモリキャッシュの設定
        memoryCache.countLimit = 100 // 最大100枚までキャッシュ
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MBまで
        
        // ディスクキャッシュのディレクトリ設定
        if let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            diskCacheURL = cacheDir.appendingPathComponent("BookCoverImages")
            // ディレクトリが存在しない場合は作成
            if !fileManager.fileExists(atPath: diskCacheURL!.path) {
                try? fileManager.createDirectory(at: diskCacheURL!, withIntermediateDirectories: true)
            }
        } else {
            diskCacheURL = nil
        }
    }
    
    /// 画像を取得（メモリ → ディスク → ネットワークの順で検索）
    func image(for url: URL) async -> UIImage? {
        let key = url.absoluteString as NSString
        
        // 1. メモリキャッシュから取得
        if let cachedImage = memoryCache.object(forKey: key) {
            return cachedImage
        }
        
        // 2. ディスクキャッシュから取得
        if let diskImage = loadFromDisk(key: key) {
            // メモリキャッシュにも保存
            memoryCache.setObject(diskImage, forKey: key)
            return diskImage
        }
        
        // 3. ネットワークから取得
        return await downloadAndCache(url: url, key: key)
    }
    
    /// ネットワークから画像をダウンロードしてキャッシュに保存
    private func downloadAndCache(url: URL, key: NSString) async -> UIImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else { return nil }
            
            // メモリキャッシュに保存
            memoryCache.setObject(image, forKey: key)
            
            // ディスクキャッシュに保存
            saveToDisk(image: image, key: key)
            
            return image
        } catch {
            print("画像のダウンロードに失敗: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// ディスクから画像を読み込む
    private func loadFromDisk(key: NSString) -> UIImage? {
        guard let diskCacheURL = diskCacheURL else { return nil }
        let fileURL = diskCacheURL.appendingPathComponent(key.sanitizedForFilename())
        
        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }
        
        return image
    }
    
    /// ディスクに画像を保存
    private func saveToDisk(image: UIImage, key: NSString) {
        guard let diskCacheURL = diskCacheURL,
              let data = image.jpegData(compressionQuality: 0.8) else {
            return
        }
        
        let fileURL = diskCacheURL.appendingPathComponent(key.sanitizedForFilename())
        try? data.write(to: fileURL)
    }
    
    /// キャッシュをクリア
    func clearCache() {
        memoryCache.removeAllObjects()
        
        if let diskCacheURL = diskCacheURL {
            try? fileManager.removeItem(at: diskCacheURL)
            try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        }
    }
}

private extension NSString {
    /// ファイル名として使用可能な文字列に変換
    func sanitizedForFilename() -> String {
        let invalidChars = CharacterSet(charactersIn: "/:?<>\\|*\"")
        return self.components(separatedBy: invalidChars).joined(separator: "_")
    }
}

/// キャッシュ機能付きのAsyncImageラッパー
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder
    
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var hasError = false
    
    var body: some View {
        Group {
            if let image = image {
                content(Image(uiImage: image))
            } else if isLoading {
                placeholder()
            } else {
                placeholder()
            }
        }
        .task {
            guard let url = url else {
                isLoading = false
                hasError = true
                return
            }
            
            isLoading = true
            hasError = false
            image = await ImageCache.shared.image(for: url)
            isLoading = false
            if image == nil {
                hasError = true
            }
        }
    }
}

