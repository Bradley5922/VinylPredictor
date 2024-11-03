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

@main
struct VinylPredictorApp: App {
    
    @State var holdingViewShow: Bool = true
    @StateObject private var viewParameters: ViewParameters = ViewParameters()
    
    var body: some Scene {
        
        WindowGroup {
            Group {
                switch viewParameters.currentRoot {
                case .testing:
//                    TesterPage()
//                    BarcodeReaderSheet()
                    EmptyView()
                case .landing:
                    LandingPage(actAsHoldingView: $holdingViewShow)
                case .home:
                    HomeScreen()
                }
            }
            .colorScheme(.dark) // force dark mode
            
            .environmentObject(viewParameters)
            
            .onAppear { // if signed in, go straight to home page
                // prevents the landing page flashing quickly if there is a session
                if (!(viewParameters.currentRoot == .testing)) {
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        Task {
                            do {
                                _ = try await supabase.auth.session
                                
                                viewParameters.currentRoot = .home
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

final class ViewParameters: ObservableObject {
    @Published var currentRoot: appRootViews = .home
}
