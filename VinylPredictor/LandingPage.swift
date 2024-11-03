//
//  ContentView.swift
//  VinylPredictor
//
//  Created by Bradley Cable on 26/10/2024.
//

import SwiftUI
import _AuthenticationServices_SwiftUI
import Supabase

struct rotatingDisk: View {
    
    @State var isDiskRotating: Bool = false
    
    var body: some View {
        Image("Disk")
            .shadow(radius: 10)
        
            .rotationEffect(Angle.degrees(isDiskRotating ? 360 : 0))
            .animation(Animation.linear(duration: 20).repeatForever(autoreverses: false), value: isDiskRotating)
            .onAppear {
                isDiskRotating = true
        }
    }
}

struct LandingPage: View {
    
    @Binding var actAsHoldingView: Bool
    @EnvironmentObject private var viewParameters: ViewParameters
    
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
                 .opacity(actAsHoldingView ? 0 : 1)
                 .animation(.easeOut(duration: 0.75), value: actAsHoldingView)
                
                rotatingDisk()
                
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
                            viewParameters.currentRoot = .home
                            
                            
                        } catch {
                            dump(error)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .padding()
                .opacity(actAsHoldingView ? 0 : 1).disabled(actAsHoldingView ? true : false)
                .animation(.easeOut(duration: 0.75), value: actAsHoldingView)
            }
        }
    }
}

#Preview {
    @Previewable @State var isHoldingView: Bool = false
    
    LandingPage(actAsHoldingView: $isHoldingView)
}

