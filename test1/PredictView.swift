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

struct PredictView: View {
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
                        Text("Predict")
                            .frame(width: 100, height: 50, alignment: .center)
                            .background(Color.white)
                            .foregroundColor(Color.black)
                            .buttonStyle(.bordered)
                            .cornerRadius(20)
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
    @State private var confidenceScores: [Float] = [] // Store confidence scores
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
        var scores: [Float] = []

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
                    scores.append(outputData[1]) // Confidence for "infected"
                }
            } catch {
                print("Error during inference: \(error.localizedDescription)")
            }
        }

        // Update confidenceScores and calculate final prediction
        DispatchQueue.main.async {
            confidenceScores = scores
            let averageConfidence = scores.reduce(0, +) / Float(scores.count)
            prediction = averageConfidence > 0.5 ? "Infected" : "Not Infected"
        }
    }

    // Crop the image into patches of size 255x255
    func cropImageIntoOverlappingPatches(image: UIImage, imageSize: CGSize, patchSize: CGSize) -> [UIImage] {
        var patches: [UIImage] = []
        
        let stepX = (Int(imageSize.width) - Int(patchSize.width)) / 4
        let stepY = (Int(imageSize.height) - Int(patchSize.height)) / 6
        
        for y in stride(from: 0, through: stepY * 6, by: stepY) {
            for x in stride(from: 0, through: stepX * 4, by: stepX) {
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

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let pixelData = context.data else { return nil }

        var normalizedData = [Float](repeating: 0, count: width * height * 3)
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = (y * width + x) * bytesPerPixel
                let red = Float(pixelData.load(fromByteOffset: pixelIndex, as: UInt8.self)) / 255.0
                let green = Float(pixelData.load(fromByteOffset: pixelIndex + 1, as: UInt8.self)) / 255.0
                let blue = Float(pixelData.load(fromByteOffset: pixelIndex + 2, as: UInt8.self)) / 255.0

                let normalizedIndex = (y * width + x) * 3
                normalizedData[normalizedIndex] = red
                normalizedData[normalizedIndex + 1] = green
                normalizedData[normalizedIndex + 2] = blue
            }
        }
        return normalizedData.withUnsafeBytes { bufferPointer in
            Data(bufferPointer)
        }
    }

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 10) {
                if let prediction = prediction {
                    Text("Final Prediction: \(prediction)")
                        .font(.title)
                        .bold()
                        .foregroundColor(.red)
                } else {
                    Text("Processing...")
                        .font(.title)
                        .bold()
                        .foregroundColor(.yellow)
                }
                
                if !confidenceScores.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Confidence Scores:")
                            .font(.headline)
                            .foregroundColor(.white)

                        ForEach(Array(confidenceScores.enumerated()), id: \.offset) { index, score in
                            Text("Patch \(index + 1): \(String(format: "%.2f", score))")
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                }

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
    func toArray<T>(type: T.Type) -> [T] {
        return self.withUnsafeBytes {
            Array($0.bindMemory(to: T.self))
        }
    }
}

struct PredictView_Previews: PreviewProvider {
    static var previews: some View {
        PredictView()
    }
}
