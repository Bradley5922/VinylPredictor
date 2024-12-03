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
            
            Toggle("Start Listening", isOn: $Shazam.isListening)
            
            Text("**Detected Songs:**")
                .bold()
                .font(.headline)
            
            ForEach(Shazam.detectedSongs, id: \.self) { song in
                VStack {
                    Text(song.title)
                    Text(song.artist)
                    Text("Apple Music Data: \(song.album)")
                }
            }
        }
        .padding()
    }
}

#Preview {
    ShazamTest()
}
