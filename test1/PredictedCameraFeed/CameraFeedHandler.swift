import AVFoundation
import UIKit

// MARK: - CameraFeedHandler
class CameraFeedHandler: CameraFeedManagerDelegate {
    var onPixelBufferOutput: ((CVPixelBuffer) -> Void)?

    func didOutput(pixelBuffer: CVPixelBuffer) {
        // Send the pixel buffer to SwiftUI for processing
        onPixelBufferOutput?(pixelBuffer)
    }

    func presentCameraPermissionsDeniedAlert() {
        print("Camera permissions denied.")
    }

    func presentVideoConfigurationErrorAlert() {
        print("Video configuration failed.")
    }

    func sessionRunTimeErrorOccured() {
        print("Session runtime error occurred.")
    }

    func sessionWasInterrupted(canResumeManually: Bool) {
        print("Session was interrupted.")
    }

    func sessionInterruptionEnded() {
        print("Session interruption ended.")
    }
}
