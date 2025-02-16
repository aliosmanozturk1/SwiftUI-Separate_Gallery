import SwiftUI

struct LoadingView: View {
    @State private var isAnimating = false
    let progress: Double
    let totalCount: Int
    let currentCount: Int
    
    var body: some View {
        ZStack {
            Color.black
                .opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(lineWidth: 8)
                        .opacity(0.3)
                        .foregroundColor(.gray)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .foregroundColor(.blue)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(Int(progress * 100))%")
                        .font(.title2)
                        .bold()
                }
                .frame(width: 150, height: 150)
                
                Text("Importing Photos")
                    .font(.title3)
                    .bold()
                
                Text("\(currentCount) of \(totalCount)")
                    .foregroundColor(.gray)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
            )
        }
    }
} 