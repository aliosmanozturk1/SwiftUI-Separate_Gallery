import UIKit

extension UIImage {
    func fixedOrientation() -> UIImage {
        // Eğer zaten doğru oryantasyonda ise direkt döndür.
        if imageOrientation == .up {
            return self
        }
        
        // Yeni bir grafik context açıp, image'ı yeniden çizerek normalize ediyoruz.
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? self
        UIGraphicsEndImageContext()
        return normalizedImage
    }
} 