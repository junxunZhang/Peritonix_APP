//
//  secondview.swift
//  test1
//
//  Created by 張晉薰 on 2024/11/28.
//

import SwiftUI

struct ContentView: View {
    
    var body: some View {
        NavigationView { // Add NavigationView to enable navigation
            TabView() {
                ZStack {
                    Image("appdesktop")
                        .resizable()
                        .scaledToFill()
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 50) {
                        NavigationLink(destination: CollectImageview()) { // Corrected destination
                            Text("Collect image")
                                .frame(width: 300, height: 100, alignment: .center)
                                .background(Color.white)
                                .foregroundColor(Color.black)
                                .cornerRadius(20)
                                .font(.title)
                                .buttonStyle(.bordered)
                        }
                        NavigationLink(destination: PredictView()) { // Corrected destination
                            Text("Predict")
                                .frame(width: 300, height: 100, alignment: .center)
                                .background(Color.gray)
                                .foregroundColor(Color.black)
                                .cornerRadius(20)
                                .font(.title)
                                .buttonStyle(.bordered)
                        }
                    }
                    
                }
            }
        }
    }
}

struct Content_view: PreviewProvider {
    static var previews: some View{
        ContentView()
    }
}
