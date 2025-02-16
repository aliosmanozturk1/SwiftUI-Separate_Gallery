import SwiftUI

struct ThumbnailView: View {
    let photo: Photo
    let photos: [Photo]
    let index: Int
    @EnvironmentObject var photoManager: PhotoManager
    @State private var thumbnailImage: UIImage?
    @State private var showingDetail = false
    
    var body: some View {
        Group {
            if let image = thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: UIScreen.main.bounds.width / 3 - 1.5, height: UIScreen.main.bounds.width / 3 - 1.5)
                    .clipped()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showingDetail = true
                    }
            } else {
                Color.gray
                    .frame(width: UIScreen.main.bounds.width / 3 - 1.5, height: UIScreen.main.bounds.width / 3 - 1.5)
            }
        }
        .task {
            thumbnailImage = await photoManager.loadThumbnail(for: photo.fileName)
        }
        .fullScreenCover(isPresented: $showingDetail) {
            PhotoDetailView(photos: photos, currentIndex: index)
                .environmentObject(photoManager)
        }
    }
}

@MainActor
class ImageLoader: ObservableObject {
    let photoManager = PhotoManager()
    
    func loadThumbnail(for photo: Photo) async -> UIImage? {
        return await photoManager.loadThumbnail(for: photo.fileName)
    }
} 
