//
//  HomeScreen.swift
//  VinylPredictor
//
//  Created by Bradley Cable on 26/10/2024.
//

import SwiftUI
import Supabase

struct HomeScreen: View {
    
    @EnvironmentObject private var rootViewSelector: RootViewSelector
    
    var body: some View {
        
        NavigationView() {
            VStack {
                Button {
                    Task {
                        await signOut()
                        rootViewSelector.currentRoot = .landing
                    }
                } label: {
                    Text("Sign Out")
                }
                
                Text("Hello, world!")
                    .font(.largeTitle)
            }
        }
    }
    
    func signOut() async  {
        do {
            try await supabase.auth.signOut()
        } catch {
            // alert user
            print(error.localizedDescription)
        }
    }
}

#Preview {
    HomeScreen()
}
