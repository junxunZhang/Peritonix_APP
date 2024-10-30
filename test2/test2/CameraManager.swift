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

            // Set manual white balance if supported
            if device.isWhiteBalanceModeSupported(.locked) {
                // Create a white balance gains setting
                let temperature: Float = 5000 // Adjust temperature as needed (value in Kelvin)
                let tint: Float = 30 // Adjust tint based on your requirements
                let gains = device.deviceWhiteBalanceGains(for: AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(temperature: temperature, tint: tint))
                device.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
            }

            // Fix exposure
            if device.isExposureModeSupported(.locked) {
                device.exposureMode = .locked
                device.setExposureModeCustom(duration: CMTimeMake(value: 1, timescale: 60), iso: 100, completionHandler: nil)
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
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("Error processing photo data")
            self.photoCompletion?(nil)
            return
        }
        
        // Save the image to the photo album
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        self.photoCompletion?(image) // Pass the captured image to the completion handler
    }
}

