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
                    
                    Task {
                        // 1-second delay, as loading can be so fast the flash of loading screen is jarring
                        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

                        do {
                            // Verify the session
                            _ = try await supabase.auth.session

                            // Initialize the UI collections on the main thread
                            await MainActor.run {
                                userCollection.array = []
                                userCollection.listened_to_seconds = []
                                userCollection.loading = true
                            }

                            // Iterate over each album as it's fetched
                            for try await (album, listenedToSeconds) in fetchCollection() {
                                // Update the UI collections on the main thread
                                await MainActor.run {
                                    userCollection.array.append(album)
                                    userCollection.listened_to_seconds.append(listenedToSeconds)
                                }
                            }

                            // Once all albums are loaded, update the loading state and navigate
                            await MainActor.run {
                                userCollection.loading = false
                                viewParameters.currentRoot = .home
                            }

                        } catch {
                            // Handle any errors that occurred during fetching
                            print("Error fetching collection: \(error.localizedDescription)")

                            await MainActor.run {
                                userCollection.loading = false
                            }
                        }

                        // Hide the holding view
                        await MainActor.run {
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
