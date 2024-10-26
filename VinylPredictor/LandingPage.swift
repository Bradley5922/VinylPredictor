//
//  ContentView.swift
//  VinylPredictor
//
//  Created by Bradley Cable on 26/10/2024.
//

import SwiftUI
import _AuthenticationServices_SwiftUI
import Supabase

struct LandingPage: View {
    
    @EnvironmentObject private var rootViewSelector: RootViewSelector
    
    @State var isDiskRotating: Bool = false
    
    var body: some View {
        ZStack() {
            Rectangle()
                .foregroundStyle(.thinMaterial)
                .background(Gradient(colors: [.blue,.teal,.green]))
                .ignoresSafeArea()
            
            VStack {
            
                VStack(alignment: .center) {
                     Text("Vinyl Predictor")
                         .font(.largeTitle)
                         .fontWeight(.bold)
                         .padding([.leading, .trailing, .top])
                         .foregroundStyle(.primary)

                     Text("Lorem ipsum dolor sit amet, consectetur adipiscing elit")
                         .font(.title3)
                         .fontWeight(.light)
                         .padding([.leading, .trailing, .bottom])
                         .foregroundColor(.secondary)
                         .multilineTextAlignment(.center)
                 }
                 .padding()
                
                
                Image("Disk")
                    .shadow(radius: 10)
                
                    .rotationEffect(Angle.degrees(isDiskRotating ? 360 : 0))
                    .animation(Animation.linear(duration: 20).repeatForever(autoreverses: false), value: isDiskRotating)
                    .onAppear {
                        isDiskRotating = true
                    }
                
                Spacer()
                
                SignInWithAppleButton { request in
                    request.requestedScopes = [.email, .fullName]
                } onCompletion: { result in
                    Task {
                        do {
                            guard let credential = try result.get().credential as? ASAuthorizationAppleIDCredential
                            else {
                                return
                            }
                            
                            guard let idToken = credential.identityToken
                                .flatMap({ String(data: $0, encoding: .utf8) })
                            else {
                                return
                            }
                            
                            // create user in Supabase User Table
                            try await supabase.auth.signInWithIdToken(
                                credentials: .init(
                                    provider: .apple,
                                    idToken: idToken
                                )
                            )
                            
                            // Change root view
                            rootViewSelector.currentRoot = .home
                            
                            
                        } catch {
                            dump(error)
                        }
                    }
                }
                .frame(width: .infinity, height: 65)
                .padding()
            }
        }
        .colorScheme(.dark)
        .onAppear() {
            let session = supabase.auth.currentSession
            
            if ((session) != nil) {
                rootViewSelector.currentRoot = .home
            }
            
            rootViewSelector.currentRoot = .landing
        }
    }
}

#Preview {
    LandingPage()
}
