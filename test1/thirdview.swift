import UIKit
import SwiftUI
import CoreData
import TensorFlowLite

// Define the Window shape to create a transparent area in the middle of the overlay
struct Window2: Shape {
    let size: CGSize
    let origin: CGPoint
    
    func path(in rect: CGRect) -> Path {
        var path = Rectangle().path(in: rect)

        // Add the transparent rectangle at the desired origin and size
        path.addRect(CGRect(origin: origin, size: size))
        return path
    }
}

struct thirdview: View {
    @State private var viewModel = ViewModel()
    @State private var navigateToImage = false // Track navigation state

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomLeading) {
                VStack {
                    ZStack {
                        // Display the camera feed in the background
                        CameraView(image: $viewModel.currentFrame)
                            .padding([.top, .leading, .trailing])
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        // Semi-transparent black overlay with transparent window
                        Rectangle()
                            .foregroundColor(Color.black.opacity(0.5))
                            .mask(
                                Window2(size: CGSize(width: 164, height: 247), origin: CGPoint(x: 22, y: UIScreen.main.bounds.height / 2 - 180))
                                    .fill(style: FillStyle(eoFill: true))
                            )
                    }

                    // Button to capture the photo
                    Button(action: {
                        // Trigger the vibration feedback when the button is pressed
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()

                        // Capture the photo and navigate if successful
                        viewModel.capturePhoto()
                        
                        if viewModel.lastCapturedImage != nil {
                            navigateToImage = true
                            
                        }
                    }) {
                        Text("Predicted")
                            .frame(width: 100, height: 50, alignment: .center)
                            .background(Color.white)
                            .foregroundColor(Color.black)
                            .buttonStyle(.bordered)
                    }
                    .padding()
                }
            }
            .navigationDestination(isPresented: $navigateToImage) {
                            // Navigate to FullScreenImageView2 when navigateToImage is true
                            FullScreenImageView2(image: viewModel.lastCapturedImage ?? UIImage())
                        }
                        .navigationBarHidden(true) // Hide the navigation bar
        }
    }
}

// Full-screen image view to display captured photo

struct FullScreenImageView2: View {
    var image: UIImage
    @State private var prediction: String? = nil
    private var interpreter: Interpreter?

    init(image: UIImage) {
        self.image = image
        interpreter = FullScreenImageView2.loadModel()
    }

    // Load the TensorFlow Lite Model
    static func loadModel() -> Interpreter? {
        guard let modelPath = Bundle.main.path(forResource: "model", ofType: "tflite") else {
            fatalError("Model not found")
        }
        
        do {
            let interpreter = try Interpreter(modelPath: modelPath)
            try interpreter.allocateTensors()
            return interpreter
        } catch {
            print("Failed to load model: \(error)")
            return nil
        }
    }

    // Process the captured image for inference
    func ProcessInputImage() {
        let patchSize = CGSize(width: 255, height: 255)
        let imageSize = CGSize(width: image.size.width, height: image.size.height)

        // Crop the image into overlapping patches
        let patches = cropImageIntoOverlappingPatches(image: image, imageSize: imageSize, patchSize: patchSize)
        var confidenceScores: [Float] = []

        // Process each patch and predict
        for patch in patches {
            guard let tensorData = preprocessImage(patch) else {
                print("Error: Could not preprocess patch.")
                continue
            }

            do {
                // Set input tensor
                try interpreter?.copy(tensorData, toInputAt: 0)

                // Run inference
                try interpreter?.invoke()

                // Get the output tensor
                let outputTensor = try interpreter?.output(at: 0)
                let outputData = outputTensor?.data.toArray(type: Float.self) ?? []

                // Extract confidence score for "infected"
                if outputData.count == 2 {
                    confidenceScores.append(outputData[1]) // Confidence for "infected"
                }
            } catch {
                print("Error during inference: \(error.localizedDescription)")
            }
        }

        // Average the confidence scores to calculate the final result
        let averageConfidence = confidenceScores.reduce(0, +) / Float(confidenceScores.count)
        let finalPrediction = averageConfidence > 0.5 ? "Infected" : "Not Infected"

        // Update the prediction for UI
        DispatchQueue.main.async {
            self.prediction = finalPrediction
        }
    }

    // Crop the image into patches of size 255x255
    // Function to crop the image into 35 overlapping patches of 255x255
    func cropImageIntoOverlappingPatches(image: UIImage, imageSize: CGSize, patchSize: CGSize) -> [UIImage] {
        var patches: [UIImage] = []
        
        // Calculate the steps for overlapping patches
        let stepX = (Int(imageSize.width) - Int(patchSize.width)) / 4  // 4 steps in the width direction
        let stepY = (Int(imageSize.height) - Int(patchSize.height)) / 6 // 6 steps in the height direction
        
        // Loop to crop the patches
        for y in stride(from: 0, through: stepY * 6, by: stepY) { // 6 steps in height
            for x in stride(from: 0, through: stepX * 4, by: stepX) { // 4 steps in width
                let origin = CGPoint(x: CGFloat(x), y: CGFloat(y))
                let rect = CGRect(origin: origin, size: patchSize)
                
                if let croppedCGImage = image.cgImage?.cropping(to: rect) {
                    patches.append(UIImage(cgImage: croppedCGImage))
                }
            }
        }
        return patches
    }


    // Preprocess a cropped patch for the TensorFlow Lite model
    func preprocessImage(_ image: UIImage) -> Data? {
        guard let cgImage = image.cgImage else { return nil }

        let width = 255
        let height = 255
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.noneSkipLast.rawValue

        var pixelData = [Float](repeating: 0, count: width * height * 3) // RGB normalized data

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Normalize pixel values to range [0, 1]
        let normalizedData = pixelData.map { Float($0) / 255.0 }
        return normalizedData.withUnsafeBytes { bufferPointer in
            Data(bufferPointer)
        }
    }

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)  // Full screen background
            
            VStack(spacing: 10) {
                // Show prediction result
                if prediction != nil {
                    Text("Prediction: \(prediction!)")
                        .font(.title)
                        .bold()
                        .foregroundColor(.red)
                } else {
                    Text("Processing...")
                        .font(.title)
                        .bold()
                        .foregroundColor(.yellow)
                }
                
                // Display the image
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(.horizontal, 5)
                    .padding(.bottom, 10)
            }
            .padding(.top, 10)
            .onAppear {
                ProcessInputImage()
            }
        }
    }
}

extension Data {
    // Convert Data to Array of Floats for TensorFlow Lite output
    func toArray<T>(type: T.Type) -> [T] {
        return self.withUnsafeBytes {
            Array($0.bindMemory(to: T.self))
        }
    }
}

struct thirdview_Previews: PreviewProvider {
    static var previews: some View{
        thirdview()
    }
}
