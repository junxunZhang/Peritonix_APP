import SwiftUI

struct CameraFeedUIView: UIViewRepresentable {
    let previewView: PreviewView

    func makeUIView(context: Context) -> PreviewView {
        return previewView
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        // Updates view when needed
    }
}
