//
//  Fuzzy Test.swift
//  VinylPredictor
//
//  Created by Bradley Cable on 13/12/2024.
//

import SwiftUI
import Fuse

struct Fuzzy_Test: View {
    
    @State var stringA: String = ""
    @State var stringB: String = ""
    
    var body: some View {
        
        VStack {
            Text("Funky Fuzzy String Comparison")
                .font(.largeTitle)
                .bold()
            
            Divider()
            
            TextField("String A", text: $stringA)
                .textFieldStyle(.roundedBorder)
            TextField("String B", text: $stringB)
                .textFieldStyle(.roundedBorder)
            
            Divider()
            
            Text("Fuzzy Score:")
                .bold()
                .font(.title2)
            
            Text("\(compareStringsTest(a: stringA, b: stringB))")
                .font(.title3)
                .fontWeight(.light)
        }
    }
}

func compareStringsTest(a: String, b: String, fuzzy: Fuse = Fuse()) -> Double {
    // Check for exact match
    if a == b {
        print("Exact match for strings, score: 0.0 => \(a) == \(b)")
        
        return 0.0 // Exact match, lowest score
    }
    
    // Perform fuzzy search
    if let fuzzyMatch = fuzzy.search(a, in: b) {
        print("Fuzzy match for strings:")
        print("\t=> Detected: \(a)")
        print("\t=> User: \(b)")
        print("\tScore: \(fuzzyMatch.score)")
        
        return fuzzyMatch.score
    }
    
    // No similarity at all, return worst-case score
    print("Strings not alike at all, score: 1.0 => \(a) VS \(b)")
    return 1.0
}

#Preview {
    Fuzzy_Test()
}
