//
//  secondview.swift
//  test1
//
//  Created by 張晉薰 on 2024/11/28.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView{
            VStack (spacing: 20) {
                NavigationLink(destination: secondview()) {
                    
                    Text("Collect image").frame(width:300, height:100, alignment: .center).background(Color.white).foregroundColor(Color.black).cornerRadius(20).font(.title).buttonStyle(.bordered)
                }
                NavigationLink(destination: thirdview()) {
                    
                    Text("Predict").frame(width:200, height:100, alignment: .center).background(Color.gray).foregroundColor(Color.black).cornerRadius(20).font(.title).buttonStyle(.bordered)
                }
                
            }
        }
    }
}
    
    

struct ContentView_Previews: PreviewProvider {
    static var previews: some View{
        ContentView()
    }
}
