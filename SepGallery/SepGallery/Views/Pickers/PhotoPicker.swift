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
        config.selectionLimit = 0
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
                parent.isLoading = true
                parent.totalCount = results.count
                parent.currentCount = 0
                parent.progress = 0.0
                
                for (index, result) in results.enumerated() {
                    if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                        do {
                            let image = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UIImage, Error>) in
                                result.itemProvider.loadObject(ofClass: UIImage.self) { object, error in
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
                            
                            parent.selectedImages = [image] // Her seferinde tek fotoğraf gönder
                            parent.currentCount = index + 1
                            parent.progress = Double(parent.currentCount) / Double(parent.totalCount)
                            
                            // Her fotoğraf için kısa bir bekleme
                            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 saniye
                        } catch {
                            print("Error loading image: \(error)")
                        }
                    }
                }
                
                parent.isLoading = false
            }
        }
    }
} 