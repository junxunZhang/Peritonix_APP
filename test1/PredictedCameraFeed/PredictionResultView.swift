import SwiftUI

struct PredictionResultView: View {
    let image: UIImage
    let prediction: String

    var body: some View {
        VStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding()

            Text("Prediction Result: \(prediction)")
                .font(.title)
                .bold()
                .foregroundColor(.red)
                .padding()

            Spacer()
        }
        .navigationBarTitle("Prediction Result", displayMode: .inline)
    }
}
