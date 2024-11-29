import Foundation
import AVFoundation
import UIKit

class CameraManager: NSObject {
    private let captureSession = AVCaptureSession()
    private var deviceInput: AVCaptureDeviceInput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var photoOutput = AVCapturePhotoOutput()
    private let systemPreferredCamera = AVCaptureDevice.default(for: .video)
    private var sessionQueue = DispatchQueue(label: "video.preview.session")
    // Add a property to hold the photo completion handler
    private var photoCompletion: ((UIImage?) -> Void)?
    
    private var isAuthorized: Bool {
        get async {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            var isAuthorized = status == .authorized
            if status == .notDetermined {
                isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
            }
            return isAuthorized
        }
    }

    private var addToPreviewStream: ((CGImage) -> Void)?
    
    lazy var previewStream: AsyncStream<CGImage> = {
        AsyncStream { continuation in
            addToPreviewStream = { cgImage in
                continuation.yield(cgImage)
            }
        }
    }()
    
    override init() {
        super.init()
        Task {
            await configureSession()
            await startSession()
        }
    }
    
    
    private func configureSession() async {
        guard await isAuthorized,
              let systemPreferredCamera,
              let deviceInput = try? AVCaptureDeviceInput(device: systemPreferredCamera)
        else { return }
        
        captureSession.beginConfiguration()
        
        defer {
            self.captureSession.commitConfiguration()
        }
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        
        guard captureSession.canAddInput(deviceInput) else {
            print("Unable to add device input to capture session.")
            return
        }
        
        guard captureSession.canAddOutput(videoOutput) else {
            print("Unable to add video output to capture session.")
            return
        }
        
        captureSession.addInput(deviceInput)
        captureSession.addOutput(videoOutput)
        
        guard captureSession.canAddOutput(photoOutput) else {
            print("Unable to add photo output to capture session.")
            return
        }
        captureSession.addOutput(photoOutput)
        
        // Fix shooting parameters
        configureFixedParameters(for: systemPreferredCamera)
    }

    private func configureFixedParameters(for device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()

            // Set continuous auto-focus if supported
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            } else if device.isFocusModeSupported(.autoFocus) {
                // Fallback to auto-focus if continuous auto-focus is not available
                device.focusMode = .autoFocus
            }
            
            
            // Set auto-fine-tune white balance if supported
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                device.whiteBalanceMode = .continuousAutoWhiteBalance
            } else {
                print("Continuous auto white balance not supported.")
            }


            if device.isExposureModeSupported(.autoExpose) {
                device.exposureMode = .autoExpose
                // You can also adjust the exposure target bias to fine-tune the auto exposure
                let exposureTargetBias: Float = 0.0 // Change this value to adjust exposure compensation (e.g., -1.0, 1.0)
                device.setExposureTargetBias(exposureTargetBias, completionHandler: nil)
            }

            // Disable auto-exposure gain (if available)
            // No need to repeat the check here as you've already set exposure mode to locked

            // Fix torch (optional, if the camera has a torch)
            if device.hasTorch && device.isTorchModeSupported(.off) {
                device.torchMode = .off
            }

            // Turn off low-light boost if supported
            if device.isLowLightBoostSupported {
                device.automaticallyEnablesLowLightBoostWhenAvailable = false
            }

            // Fix zoom level (if applicable)
            if device.activeFormat.videoMaxZoomFactor > 1.0 {
                device.videoZoomFactor = 1.0
            }

            device.unlockForConfiguration()
        } catch {
            print("Failed to lock device for configuration: \(error)")
        }
    }



    
    private func startSession() async {
        guard await isAuthorized else { return }
        captureSession.startRunning()
    }

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        let photoSettings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: photoSettings, delegate: self)
        
        self.photoCompletion = completion // Capture the photo and pass it back
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        
        // Set the video orientation based on the current device orientation
        connection.videoRotationAngle = 270 // or .landscapeRight based on your requirements
        
        guard let currentFrame = sampleBuffer.cgImage else { return }
        addToPreviewStream?(currentFrame)
        
        
    }

}


extension CameraManager: AVCapturePhotoCaptureDelegate {

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {

        guard error == nil else {
            print("Error capturing photo: \(String(describing: error))")
            self.photoCompletion?(nil)
            return
        }

        // Convert the captured photo data to UIImage
        guard let imageData = photo.fileDataRepresentation(),
              let fullImage = UIImage(data: imageData) else {
            print("Error processing photo data")
            self.photoCompletion?(nil)
            return
        }

        // Correct the image orientation
        let correctedImage = fixImageOrientation(image: fullImage)

        // Define the target size for cropping (450x680 pixels)
        let targetSize = CGSize(width: 450, height: 680)

        // Calculate the cropping rectangle centered in the full image
        let cropRectInImage = CGRect(
            x: (correctedImage.size.width - targetSize.width) / 2 - 305,  // Center and adjust horizontally
            y: (correctedImage.size.height - targetSize.height) / 2 + 97, // Center and adjust vertically
            width: targetSize.width,
            height: targetSize.height
        )

        // Crop the image
        if let croppedCGImage = correctedImage.cgImage?.cropping(to: cropRectInImage) {
            let croppedImage = UIImage(cgImage: croppedCGImage)

            // Save the cropped image to the photo album
            UIImageWriteToSavedPhotosAlbum(croppedImage, nil, nil, nil)
            self.photoCompletion?(croppedImage)  // Return the cropped image
        } else {
            print("Failed to crop image")
            self.photoCompletion?(nil)
        }
    }
    
    // Fix the image orientation function
    private func fixImageOrientation(image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }

        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalizedImage ?? image
    }
}




