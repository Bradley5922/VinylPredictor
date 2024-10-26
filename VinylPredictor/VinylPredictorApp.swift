//
//  VinylPredictorApp.swift
//  VinylPredictor
//
//  Created by Bradley Cable on 26/10/2024.
//

import SwiftUI
import Supabase

enum appRootViews {
    case landing
    case home
}

final class RootViewSelector: ObservableObject {
    
    @Published var currentRoot: appRootViews = .home
    
}

@main
struct VinylPredictorApp: App {
    
    @StateObject private var rootViewSelector: RootViewSelector = RootViewSelector()
    
    var body: some Scene {
        
        WindowGroup {
            Group {
                switch rootViewSelector.currentRoot {
                case .landing:
                    LandingPage()
                    
                case .home:
                    HomeScreen()
                }
            }
            .environmentObject(rootViewSelector)
            
        }
    }
}
