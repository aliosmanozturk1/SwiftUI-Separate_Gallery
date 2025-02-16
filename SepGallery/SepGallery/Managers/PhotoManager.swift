import Foundation
import UIKit
import UniformTypeIdentifiers
import ImageIO

@MainActor
class PhotoManager: ObservableObject {
    @Published private(set) var photos: [Photo] = []
    private let fileManager = FileManager.default
    private let thumbnailSize = CGSize(width: 300, height: 300)
    private let thumbnailCache = NSCache<NSString, UIImage>()
    
    private var photosDirectory: URL? {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("Photos")
    }
    
    private var thumbnailsDirectory: URL? {
        photosDirectory?.appendingPathComponent("Thumbnails")
    }
    
    init() {
        createDirectoriesIfNeeded()
        loadPhotos()
    }
    
    private func createDirectoriesIfNeeded() {
        guard let photosDirectory = photosDirectory,
              let thumbnailsDirectory = thumbnailsDirectory else { return }
        
        let directories = [photosDirectory, thumbnailsDirectory]
        
        for directory in directories {
            if !fileManager.fileExists(atPath: directory.path) {
                do {
                    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                } catch {
                    print("Error creating directory at \(directory.path): \(error)")
                }
            }
        }
    }
    
    private func loadPhotos() {
        guard let photosDirectory else { return }
        
        do {
            let metadataURL = photosDirectory.appendingPathComponent("metadata.json")
            
            if fileManager.fileExists(atPath: metadataURL.path),
               let data = try? Data(contentsOf: metadataURL) {
                photos = try JSONDecoder().decode([Photo].self, from: data)
            }
        } catch {
            print("Error loading photos: \(error)")
        }
    }
    
    private func saveMetadata() {
        guard let photosDirectory else { return }
        
        do {
            let metadataURL = photosDirectory.appendingPathComponent("metadata.json")
            let data = try JSONEncoder().encode(photos)
            try data.write(to: metadataURL)
        } catch {
            print("Error saving metadata: \(error)")
        }
    }
    
    func saveImage(_ image: UIImage) async throws -> Photo {
        guard let photosDirectory = photosDirectory,
              let thumbnailsDirectory = thumbnailsDirectory else {
            throw NSError(domain: "PhotoManager", code: 1)
        }
        
        let fileName = UUID().uuidString
        
        return try await Task.detached(priority: .userInitiated) {
            // 1. Thumbnail oluştur (orijinal image'ı modifiye etmeden)
            let thumbnail = image.preparingThumbnail(of: CGSize(width: 300, height: 300))
            
            // 2. Orijinal image data'sını al
            guard let originalData = image.imageData else {
                throw NSError(domain: "PhotoManager", code: 2)
            }
            
            // 3. Dosya uzantısını belirle
            let fileExtension = originalData.imageFormat ?? "jpg"
            
            // 4. Dosya URL'lerini oluştur
            let originalURL = photosDirectory.appendingPathComponent("\(fileName).\(fileExtension)")
            let thumbnailURL = thumbnailsDirectory.appendingPathComponent("\(fileName)_thumb.jpg")
            
            // 5. Thumbnail kaydet
            if let thumbnail = thumbnail,
               let thumbnailData = thumbnail.jpegData(compressionQuality: 0.7) {
                try thumbnailData.write(to: thumbnailURL)
            }
            
            // 6. Orijinal dosyayı kaydet
            try originalData.write(to: originalURL)
            
            // 7. Photo objesi oluştur
            let photo = Photo(fileName: fileName, fileExtension: fileExtension)
            
            // 8. Main thread'de photos array'ini güncelle
            await MainActor.run {
                self.photos.append(photo)
                self.saveMetadata()
            }
            
            return photo
        }.value
    }
    
    func loadThumbnail(for fileName: String) async -> UIImage? {
        // Önce cache'e bak
        if let cached = thumbnailCache.object(forKey: fileName as NSString) {
            return cached
        }
        
        return try? await Task.detached(priority: .userInitiated) {
            guard let thumbnailsDirectory = await self.thumbnailsDirectory else { return nil }
            let thumbnailURL = thumbnailsDirectory.appendingPathComponent("\(fileName)_thumb.jpg")
            
            guard let data = try? Data(contentsOf: thumbnailURL),
                  let image = UIImage(data: data) else {
                return nil
            }
            
            let fixedImage = image.fixedOrientation()
            
            // Cache'e kaydet
            await MainActor.run {
                self.thumbnailCache.setObject(fixedImage, forKey: fileName as NSString)
            }
            
            return fixedImage
        }.value
    }
    
    func loadOriginalImage(fileName: String, fileExtension: String) async -> UIImage? {
        return try? await Task.detached(priority: .userInitiated) {
            guard let photosDirectory = await self.photosDirectory else { return nil }
            let originalURL = photosDirectory.appendingPathComponent("\(fileName).\(fileExtension)")
            
            guard let imageSource = CGImageSourceCreateWithURL(originalURL as CFURL, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                return nil
            }
            
            // EXIF orientation bilgisini al
            let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any]
            let orientation = properties?[kCGImagePropertyOrientation] as? UInt32 ?? 1
            
            // Orientation değerini düzelt
            let correctedOrientation: UIImage.Orientation
            switch orientation {
            case 1: correctedOrientation = .up
            case 2: correctedOrientation = .upMirrored
            case 3: correctedOrientation = .down
            case 4: correctedOrientation = .downMirrored
            case 5: correctedOrientation = .leftMirrored
            case 6: correctedOrientation = .right
            case 7: correctedOrientation = .rightMirrored
            case 8: correctedOrientation = .left
            default: correctedOrientation = .up
            }
            
            return UIImage(cgImage: cgImage, scale: 1.0, orientation: correctedOrientation)
        }.value
    }
}

extension UIImage {
    var imageData: Data? {
        guard let cgImage = self.cgImage else { return nil }
        let data = NSMutableData()
        
        // ImageIO ile metadata'yı koruyarak kaydetme
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        
        let imageProperties = [
            kCGImagePropertyOrientation: self.imageOrientation.cgImagePropertyOrientation.rawValue
        ] as [CFString : Any] as CFDictionary
        
        CGImageDestinationAddImage(destination, cgImage, imageProperties)
        
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}

extension UIImage.Orientation {
    var cgImagePropertyOrientation: CGImagePropertyOrientation {
        switch self {
        case .up: return .right
        case .upMirrored: return .rightMirrored
        case .down: return .left
        case .downMirrored: return .leftMirrored
        case .left: return .down
        case .leftMirrored: return .downMirrored
        case .right: return .up
        case .rightMirrored: return .upMirrored
        @unknown default: return .right
        }
    }
}

extension Data {
    var imageFormat: String? {
        var format: String?
        
        // HEIC kontrolü
        if self.starts(with: [0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x63]) {
            format = "heic"
        }
        // PNG kontrolü
        else if self.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            format = "png"
        }
        // JPEG kontrolü
        else if self.starts(with: [0xFF, 0xD8, 0xFF]) {
            format = "jpg"
        }
        
        return format
    }
}
