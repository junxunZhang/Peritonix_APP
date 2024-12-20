import SwiftUI
import AVFoundation

struct PreviewViewWrapper: UIViewRepresentable {
    var session: AVCaptureSession?

    func makeUIView(context: Context) -> UIView {
        let previewView = PreviewView()
        previewView.session = session
        return previewView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // No updates needed
    }
}
