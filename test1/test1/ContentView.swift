import UIKit
import SwiftUI
import CoreData

// Define the Window shape to create a transparent area in the middle of the overlay
struct Window: Shape {
    let size: CGSize
    let origin: CGPoint
    
    func path(in rect: CGRect) -> Path {
        var path = Rectangle().path(in: rect)

        // Add the transparent rectangle at the desired origin and size
        path.addRect(CGRect(origin: origin, size: size))
        return path
    }
}

struct ContentView: View {
    
    @State private var viewModel = ViewModel()
    @State private var isImageFullScreen = false  // Track whether the image is full-screen
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomLeading) {
                
                VStack {
                    ZStack {
                        // Display the camera feed in the background
                        CameraView(image: $viewModel.currentFrame)
                            .padding([.top, .leading, .trailing])
                            .frame(maxWidth: .infinity, maxHeight: .infinity) // Expand to full available space
                        
                        // Semi-transparent black overlay with transparent window
                        Rectangle()
                            .foregroundColor(Color.black.opacity(0.5)) // 50% transparent black overlay
                            .mask(
                                // Adjust transparent window to match screenshot positioning
                                Window(size: CGSize(width: 164, height: 247), origin: CGPoint(x: 22, y: UIScreen.main.bounds.height / 2 - 180))
                                    .fill(style: FillStyle(eoFill: true)) // Apply masking for transparent window
                            )
                    }

                    // Button to capture the photo
                    Button(action: {
                        // Trigger the vibration feedback when the button is pressed
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        
                        // Trigger photo capture
                        viewModel.capturePhoto()
                    }) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 70, height: 70)
                    }
                    .padding()
                }
                
                // Small preview window for the last captured photo
                if let lastImage = viewModel.lastCapturedImage {
                    NavigationLink(destination: FullScreenImageView(image: lastImage)) {
                        Image(uiImage: lastImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 70, height: 70)
                            .border(Color.white, width: 2)
                            .cornerRadius(3.0)
                            .padding()
                    }
                }
            }
            .navigationBarHidden(true)  // Hide the navigation bar
        }
    }
}

// Full-screen image view to display captured photo
struct FullScreenImageView: View {
    var image: UIImage
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)  // Full screen background
            
            VStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(.horizontal, 0)  // Optional, reduce padding to the sides
                    .padding(.bottom, 50)  // Adjust bottom padding for more space for the button
            }
        }
    }
}
