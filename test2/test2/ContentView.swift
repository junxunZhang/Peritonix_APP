//
//  ContentView.swift
//  Peritonix
//
//  Created by 張晉薰 on 2024/9/11.
//
import UIKit
import SwiftUI
import CoreData

struct ContentView: View {
    
    @State private var viewModel = ViewModel()
    @State private var isImageFullScreen = false  // Track whether the image is full-screen
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomLeading) {
                
                VStack {
                    // Display the camera feed
                    CameraView(image: $viewModel.currentFrame)
                        .padding([.top, .leading, .trailing])
                        .frame(maxWidth: .infinity, maxHeight: .infinity) // Expand to full available space
                    
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

struct ContentView_Peview: PreviewProvider {
    static var previews: some View{
        ContentView()
        
    }
}
