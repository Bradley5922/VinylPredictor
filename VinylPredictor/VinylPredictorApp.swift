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


final class ViewParameters: ObservableObject {
    @Published var currentRoot: appRootViews = .landing
}


@main
struct VinylPredictorApp: App {
    
    @State var holdingViewShow: Bool = true
    @StateObject private var viewParameters: ViewParameters = ViewParameters()
    
    @StateObject var userCollection: AlbumCollectionModel = AlbumCollectionModel()
    
    // Create an init ShazamViewModel, incase the user needs it, so it is ready to run in background
    @StateObject private var shazamViewModel: ShazamViewModel = ShazamViewModel()
    
    var body: some Scene {
        
        WindowGroup {
            Group {
                switch viewParameters.currentRoot {
                case .testing:
                    Fuzzy_Test()
//                    ShazamTest()
//                    EmptyView()
                case .landing:
                    LandingPage(actAsHoldingView: $holdingViewShow)
                case .home:
                    HomeScreen()
                }
            }
            
            .onAppear { // if signed in, go straight to home page
                // prevents the landing page flashing quickly if there is a session
                if (!(viewParameters.currentRoot == .testing)) {
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        Task {
                            do {
                                _ = try await supabase.auth.session
                                
                                // fetch the users collection, ready to be used
                                if case .success(let collection) = await fetchCollection() {
                                    let albums = collection.map { $0.0 }
                                    userCollection.array = albums
                                    userCollection.listened_to_seconds = collection.map { $0.1 }
                                    
                                    userCollection.loading = false
                                }
                                
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
            .colorScheme(.dark) // Force dark mode on all views
            .environmentObject(viewParameters)
            .environmentObject(shazamViewModel)
            .environment(userCollection)
            
        }
    }
}
