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
    case testing
}

final class RootViewSelector: ObservableObject {
    
    @Published var currentRoot: appRootViews = .landing
    
}

@main
struct VinylPredictorApp: App {
    
    @State var holdingViewShow: Bool = true
    @StateObject private var rootViewSelector: RootViewSelector = RootViewSelector()
    
    var body: some Scene {
        
        WindowGroup {
            Group {
                switch rootViewSelector.currentRoot {
                case .testing:
//                    TesterPage()
                    EmptyView()
                case .landing:
                    LandingPage(actAsHoldingView: $holdingViewShow)
                case .home:
                    HomeScreen()
                }
            }
            .colorScheme(.dark) // force dark mode
            .environmentObject(rootViewSelector)
            
            .onAppear { // if signed in, go straight to home page
                // prevents the landing page flashing quickly if there is a session
                if (!(rootViewSelector.currentRoot == .testing)) {
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        Task {
                            do {
                                _ = try await supabase.auth.session
                                
                                rootViewSelector.currentRoot = .home
                            } catch {
                                // No session, throws error
                                print("Error: \(error.localizedDescription)")
                            }
                            
                            holdingViewShow = false
                        }

                    }
                }
            }
            
        }
    }
}
