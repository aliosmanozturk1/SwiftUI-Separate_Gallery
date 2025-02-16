import SwiftUI
import PhotosUI

struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var selectedImages: [UIImage]
    @Binding var isLoading: Bool
    @Binding var progress: Double
    @Binding var currentCount: Int
    @Binding var totalCount: Int
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 0 // Çoklu seçim
        config.filter = .images
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker
        
        init(_ parent: PhotoPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard !results.isEmpty else { return }
            
            Task { @MainActor in
                // UI başlangıç durumu
                parent.isLoading = true
                parent.totalCount = results.count
                parent.currentCount = 0
                parent.progress = 0.0
                
                // Her fotoğrafı sırayla işle
                for (index, result) in results.enumerated() {
                    do {
                        // 1. Fotoğrafı yükle
                        let image = try await loadImage(from: result.itemProvider)
                        
                        // 2. PhotoManager'a kaydet
                        parent.selectedImages = [image]
                        
                        // 3. Progress güncelle
                        parent.currentCount = index + 1
                        parent.progress = Double(index + 1) / Double(results.count)
                        
                        // 4. Belleği temizle
                        if parent.selectedImages.count > 0 {
                            parent.selectedImages.removeAll()
                        }
                        
                        // 5. Kısa bir bekleme ile sisteme nefes aldır
                        try? await Task.sleep(for: .milliseconds(100))
                    } catch {
                        print("Error processing image at index \(index): \(error)")
                    }
                }
                
                // İşlem bitti
                parent.isLoading = false
            }
        }
        
        private func loadImage(from provider: NSItemProvider) async throws -> UIImage {
            try await withCheckedThrowingContinuation { continuation in
                provider.loadObject(ofClass: UIImage.self) { object, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let image = object as? UIImage else {
                        continuation.resume(throwing: NSError(domain: "PhotoPicker", code: 1))
                        return
                    }
                    
                    continuation.resume(returning: image)
                }
            }
        }
    }
}
