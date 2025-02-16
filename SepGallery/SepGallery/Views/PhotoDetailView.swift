import SwiftUI

struct PhotoDetailView: View {
    let photos: [Photo]
    let currentIndex: Int
    @Environment(\.dismiss) private var dismiss
    @StateObject private var imageLoader = ImageLoader()
    @State private var image: UIImage?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var draggedOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var currentPhotoIndex: Int
    @State private var horizontalDragOffset: CGFloat = 0
    @State private var dragDirection: DragDirection = .none
    
    private enum DragDirection {
        case none, vertical, horizontal
    }
    
    init(photos: [Photo], currentIndex: Int) {
        self.photos = photos
        self.currentIndex = currentIndex
        _currentPhotoIndex = State(initialValue: currentIndex)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .opacity(1 - Double(abs(draggedOffset.height) / 200))
                    .edgesIgnoringSafeArea(.all)
                
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .offset(draggedOffset)
                        .offset(x: horizontalDragOffset)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if scale > 1 {
                                        let newOffset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                        offset = limitOffset(newOffset, geometry: geometry)
                                    } else {
                                        // İlk harekette yönü belirle
                                        if dragDirection == .none {
                                            let horizontal = abs(value.translation.width)
                                            let vertical = abs(value.translation.height)
                                            
                                            if horizontal > vertical && horizontal > 10 {
                                                dragDirection = .horizontal
                                            } else if vertical > horizontal && vertical > 10 {
                                                dragDirection = .vertical
                                            }
                                        }
                                        
                                        // Belirlenen yöne göre hareketi uygula
                                        switch dragDirection {
                                        case .vertical:
                                            let translation = value.translation.height
                                            if translation >= 0 {
                                                isDragging = true
                                                draggedOffset = CGSize(
                                                    width: 0,
                                                    height: translation
                                                )
                                            }
                                        case .horizontal:
                                            horizontalDragOffset = value.translation.width
                                        case .none:
                                            break
                                        }
                                    }
                                }
                                .onEnded { value in
                                    if scale > 1 {
                                        lastOffset = offset
                                    } else {
                                        switch dragDirection {
                                        case .vertical:
                                            let translation = value.translation.height
                                            if translation >= 0 {
                                                if translation > 20 || value.velocity.height > 200 {
                                                    withAnimation(.easeOut(duration: 0.2)) {
                                                        draggedOffset = CGSize(
                                                            width: 0,
                                                            height: 1000
                                                        )
                                                    }
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                                        dismiss()
                                                    }
                                                } else {
                                                    withAnimation(.spring(response: 0.3)) {
                                                        draggedOffset = .zero
                                                    }
                                                }
                                            }
                                        case .horizontal:
                                            let horizontalTranslation = value.translation.width
                                            if abs(horizontalTranslation) > geometry.size.width / 3 {
                                                if horizontalTranslation > 0 && currentPhotoIndex > 0 {
                                                    withAnimation(.spring(response: 0.3)) {
                                                        horizontalDragOffset = geometry.size.width
                                                    }
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                        currentPhotoIndex -= 1
                                                        horizontalDragOffset = 0
                                                        loadCurrentImage()
                                                    }
                                                } else if horizontalTranslation < 0 && currentPhotoIndex < photos.count - 1 {
                                                    withAnimation(.spring(response: 0.3)) {
                                                        horizontalDragOffset = -geometry.size.width
                                                    }
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                        currentPhotoIndex += 1
                                                        horizontalDragOffset = 0
                                                        loadCurrentImage()
                                                    }
                                                } else {
                                                    withAnimation(.spring(response: 0.3)) {
                                                        horizontalDragOffset = 0
                                                    }
                                                }
                                            } else {
                                                withAnimation(.spring(response: 0.3)) {
                                                    horizontalDragOffset = 0
                                                }
                                            }
                                        case .none:
                                            break
                                        }
                                        
                                        dragDirection = .none
                                        isDragging = false
                                    }
                                }
                        )
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    
                                    let newScale = min(max(scale * delta, 1), 4)
                                    let deltaScale = newScale / scale
                                    scale = newScale
                                    
                                    offset = CGSize(
                                        width: offset.width * deltaScale,
                                        height: offset.height * deltaScale
                                    )
                                    lastOffset = offset
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                    validateOffset(geometry: geometry)
                                }
                        )
                        .gesture(
                            TapGesture(count: 2)
                                .onEnded {
                                    withAnimation(.spring()) {
                                        if scale > 1 {
                                            scale = 1
                                            offset = .zero
                                            lastOffset = .zero
                                        } else {
                                            scale = 2
                                        }
                                    }
                                }
                        )
                } else {
                    ProgressView()
                }
            }
        }
        .task {
            loadCurrentImage()
        }
        .navigationBarHidden(true)
        .statusBar(hidden: true)
    }
    
    private func loadCurrentImage() {
        // Önceki görüntüyü temizle
        image = nil
        
        Task {
            // Yeni görüntüyü yükle
            image = await imageLoader.loadOriginalImage(for: photos[currentPhotoIndex])
        }
    }
    
    private func validateOffset(geometry: GeometryProxy) {
        withAnimation(.spring()) {
            let maxOffset = maxAllowableOffset(geometry: geometry)
            offset = limitOffset(offset, geometry: geometry)
            lastOffset = offset
        }
    }
    
    private func limitOffset(_ proposedOffset: CGSize, geometry: GeometryProxy) -> CGSize {
        let maxOffset = maxAllowableOffset(geometry: geometry)
        return CGSize(
            width: proposedOffset.width.clamped(to: -maxOffset.width...maxOffset.width),
            height: proposedOffset.height.clamped(to: -maxOffset.height...maxOffset.height)
        )
    }
    
    private func maxAllowableOffset(geometry: GeometryProxy) -> CGSize {
        let imageSize = geometry.size
        let scaledImageSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
        
        return CGSize(
            width: max(0, (scaledImageSize.width - imageSize.width) / 2),
            height: max(0, (scaledImageSize.height - imageSize.height) / 2)
        )
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

extension ImageLoader {
    func loadOriginalImage(for photo: Photo) async -> UIImage? {
        return await photoManager.loadOriginalImage(fileName: photo.fileName, fileExtension: photo.fileExtension)
    }
} 
