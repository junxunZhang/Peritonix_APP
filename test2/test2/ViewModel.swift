//
//  ViewModel.swift
//  Peritonix
//
//  Created by 張晉薰 on 2024/9/11.
//
import Foundation
import CoreImage
import Observation
import UIKit

@Observable
class ViewModel {
    // Current frame from the camera feed
    var currentFrame: CGImage?
    
    // Store the last captured image
    var lastCapturedImage: UIImage?  // This is a stored property now
    
    private let cameraManager = CameraManager()

    init() {
        Task {
            await handleCameraPreviews()
        }
    }

    func handleCameraPreviews() async {
        for await image in cameraManager.previewStream {
            Task { @MainActor in
                currentFrame = image
            }
        }
    }

    // Capture photo and store it in lastCapturedImage
    func capturePhoto() {
        cameraManager.capturePhoto { image in
            self.lastCapturedImage = image // Save the captured image
        }
    }
}
