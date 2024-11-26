//
//  ShazamTest.swift
//  VinylPredictor
//
//  Created by Bradley Cable on 26/11/2024.
//

import SwiftUI

struct ShazamTest: View {
    
    @EnvironmentObject var Shazam: ShazamViewModel
    
    var body: some View {
        VStack {
            Text("Shazam Test")
                .foregroundStyle(.primary)
                .font(.largeTitle)
                .bold()
            
            Image(systemName: "shazam.logo.fill")
                .resizable()
                .foregroundStyle(.blue)
                .frame(width: 150, height: 150)
                .padding(50)
            
            Button {
                Shazam.startListening()
            } label: {
                RoundedRectangle(cornerRadius: 8)
                    .foregroundStyle(.green)
                    .overlay {
                        Text("Start Listening")
                            .foregroundStyle(.white)
                    }
                    .frame(height: 50)
            }
            .padding()
            
            Button {
                Shazam.stopListening()
            } label: {
                RoundedRectangle(cornerRadius: 8)
                    .foregroundStyle(.red)
                    .overlay {
                        Text("Stop Listening")
                            .foregroundStyle(.white)
                    }
                    .frame(height: 50)
            }
            .padding()
        }
        .padding()
    }
}

#Preview {
    ShazamTest()
}
