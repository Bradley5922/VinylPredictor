//
//  Profile.swift
//  VinylPredictor
//
//  Created by Bradley Cable on 27/10/2024.
//

import SwiftUI

struct Profile: View {
    
    var body: some View {
        VStack {
            Text("Hello, Profile!")
        }
    }

}

struct signOutToolBarItem: View {
    
    @EnvironmentObject private var rootViewSelector: RootViewSelector
    
    var body: some View {
        Button {
            Task {
                await signOut()
                rootViewSelector.currentRoot = .landing
            }
        } label: {
            Text("Sign Out")
        }
    }
    
    // Adding comments to this, as it is my first time using async/await in Swift
    // 'async' allows this function to run without blocking other code.
    func signOut() async {
        do {
            
            // 'await' pauses execution of this function until the sign-out (the await call) operation completes.
            try await supabase.auth.signOut() // performs the actual sign-out on the server
            
            print("Sign Out Complete") // this code will only run after and when sign out is successful
            
        } catch {
            // Ideally, show an alert to the user rather than just printing.
            print(error.localizedDescription)
        }
    }
}

#Preview {
    Profile()
}
