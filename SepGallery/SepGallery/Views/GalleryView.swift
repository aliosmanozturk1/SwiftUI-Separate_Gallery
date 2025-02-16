import SwiftUI

struct GalleryView: View {
    @StateObject private var photoManager = PhotoManager()
    @State private var isSelectionMode = false
    @State private var showingPhotoPicker = false
    @State private var selectedImages: [UIImage] = []
    @State private var isLoading = false
    @State private var progress = 0.0
    @State private var currentCount = 0
    @State private var totalCount = 0
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    if photoManager.photos.isEmpty {
                        Text("No photos yet")
                            .foregroundStyle(.secondary)
                            .frame(maxHeight: .infinity)
                    } else {
                        LazyVGrid(columns: columns, spacing: 1) {
                            ForEach(Array(photoManager.photos.enumerated()), id: \.element.id) { index, photo in
                                ThumbnailView(photo: photo, photos: photoManager.photos, index: index)
                                    .onAppear {
                                        Task.detached(priority: .background) {
                                            await withTaskGroup(of: Void.self) { group in
                                                let start = index + 1
                                                let end = await min(index + 6, photoManager.photos.count)
                                                for i in start..<end {
                                                    let nextPhawaitOto = await photoManager.photos[i]
                                                    group.addTask {
                                                        _ = await photoManager.loadThumbnail(for: nextPhawaitOto.fileName)
                                                        await Task.yield()
                                                    }
                                                }
                                            }
                                        }
                                    }
                            }
                        }
                    }
                }
                .navigationTitle("Photos")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 16) {
                            Button(action: {
                                showingPhotoPicker = true
                            }) {
                                Image(systemName: "plus")
                            }
                            .disabled(isLoading)
                            
                            Button(action: {
                                // Camera action gelecek
                            }) {
                                Image(systemName: "camera")
                            }
                            .disabled(isLoading)
                            
                            Button(action: {
                                isSelectionMode.toggle()
                            }) {
                                Image(systemName: "checkmark.circle")
                            }
                            .disabled(isLoading)
                        }
                    }
                }
                
                if isLoading {
                    LoadingView(
                        progress: progress,
                        totalCount: totalCount,
                        currentCount: currentCount
                    )
                }
            }
            .sheet(isPresented: $showingPhotoPicker) {
                PhotoPicker(
                    selectedImages: $selectedImages,
                    isLoading: $isLoading,
                    progress: $progress,
                    currentCount: $currentCount,
                    totalCount: $totalCount
                )
            }
            .onChange(of: selectedImages) { newImages in
                guard let image = newImages.first else { return }
                
                Task {
                    do {
                        try await photoManager.saveImage(image)
                    } catch {
                        print("Error saving image: \(error)")
                    }
                    selectedImages.removeAll()
                }
            }
        }
        .environmentObject(photoManager)
    }
}

#Preview {
    GalleryView()
} 
