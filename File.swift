//
//  File.swift
//  VinylPredictor
//
//  Created by Bradley Cable on 13/12/2024.
//


func compareStrings(a: String, b: String, fuzzy: Fuse = Fuse()) -> Double {
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