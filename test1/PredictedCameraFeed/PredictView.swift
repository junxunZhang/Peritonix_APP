import SwiftUI
import AVFoundation
import TensorFlowLite

struct PredictView: View {
    @State private var currentFrame: UIImage? = nil
    @State private var capturedImage: UIImage? = nil
    @State private var predictionResult: String = ""
    @State private var navigateToResult = false

    private var cameraFeedManager: CameraFeedManager!
    private var cameraHandler: CameraFeedHandler!
    private var interpreter: Interpreter?

    init() {
        let previewView = PreviewView()
        self.cameraHandler = CameraFeedHandler()
        self.cameraFeedManager = CameraFeedManager(previewView: previewView)
        self.cameraFeedManager.delegate = cameraHandler

        // Load TensorFlow Lite model
        self.interpreter = try? Interpreter(modelPath: Bundle.main.path(forResource: "model", ofType: "tflite")!)
        try? interpreter?.allocateTensors()
    }

    var body: some View {
        NavigationView {
            ZStack {
                CameraFeedUIView(previewView: cameraFeedManager.previewView)

                VStack {
                    Spacer()
                    Button("Capture and Predict") {
                        captureFrameAndPredict()
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                }
            }
            .onAppear {
                cameraFeedManager.checkCameraConfigurationAndStartSession()
                cameraHandler.onPixelBufferOutput = { pixelBuffer in
                    currentFrame = UIImage(ciImage: CIImage(cvPixelBuffer: pixelBuffer))
                }
            }
            .onDisappear {
                cameraFeedManager.stopSession()
            }
            .navigationDestination(isPresented: $navigateToResult) {
                if let capturedImage = capturedImage {
                    PredictionResultView(image: capturedImage, prediction: predictionResult)
                }
            }
        }
    }

    // MARK: Capture and Predict Logic
    private func captureFrameAndPredict() {
        guard let frame = currentFrame else {
            print("No frame available to capture.")
            return
        }

        // Save the captured image
        self.capturedImage = frame

        // Run the TensorFlow Lite model to predict
        if let output = runModelOnImage(frame) {
            self.predictionResult = output
        } else {
            self.predictionResult = "Prediction failed"
        }

        // Navigate to result page
        self.navigateToResult = true
    }

    private func runModelOnImage(_ image: UIImage) -> String? {
        guard let interpreter = interpreter else {
            print("Model not loaded.")
            return nil
        }

        guard let inputData = preprocessImage(image) else {
            print("Error preprocessing image.")
            return nil
        }

        do {
            try interpreter.copy(inputData, toInputAt: 0)
            try interpreter.invoke()
            let outputTensor = try interpreter.output(at: 0)
            let output = outputTensor.data.toArray(type: Float.self)

            // Extract the confidence for "infected"
            return output[1] > 0.5 ? "Infected" : "Not Infected"
        } catch {
            print("Error running model: \(error)")
            return nil
        }
    }

    // MARK: Preprocessing Image for TensorFlow Lite
    private func preprocessImage(_ image: UIImage) -> Data? {
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
        return normalizedData.withUnsafeBytes { Data($0) }
    }
}


// MARK: - Data Extension for TensorFlow Lite
extension Data {
    func toArray<T>(type: T.Type) -> [T] {
        return self.withUnsafeBytes {
            Array($0.bindMemory(to: T.self))
        }
    }
}

