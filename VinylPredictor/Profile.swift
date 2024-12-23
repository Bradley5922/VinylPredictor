//
//  Profile.swift
//  VinylPredictor
//
//  Created by Bradley Cable on 27/10/2024.
//

import SwiftUI
import _PhotosUI_SwiftUI

struct Profile: View {
    
    @StateObject var profile_metadata: ProfileMetadata = ProfileMetadata()

    var emailPrefix: String {
        if let email = supabase.auth.currentSession?.user.email,
           let atIndex = email.firstIndex(of: "@") {
            return String(email[..<atIndex])
        } else {
            return "User Profile"
        }
    }

    var body: some View {
        NavigationView {
            VStack {
                if let _ = profile_metadata.user_id {

                    ProfilePicture(profile_metadata: profile_metadata)
                        .frame(width: 175, height: 175)
                        .background(Color.gray)
                        .clipShape(Circle())
                    
                    Text(emailPrefix)
                        .font(.title)
                        .bold()
                    
                    Divider()
                    
                    AllowPublicCollectionToggle(profile_metadata: profile_metadata)
                    AllowPublicListeningHistory(profile_metadata: profile_metadata)

                    Spacer()
                    
                    Text("Thank you for using Vinyl Predictor!")
                        .foregroundStyle(.secondary)
                        .fontWeight(.light)
                    Text("Developed by Bradley Cable")
                        .italic()
                        .fontWeight(.ultraLight)
                        .foregroundStyle(.tertiary)
                    
                    Divider()
                } else {
                    Spacer()
                    
                    Text("Loading...")
                        .font(.largeTitle)
                        .italic()
                    
                    Spacer()
                }
            }
            .padding()
            .task {
                // Use .task instead of onAppear for SwiftUI concurrency
                await profile_metadata.fetch()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    signOutToolBarItem()
                }

                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(destination: UserSearch()) {
                        Text("User Search")
                    }
                }
            }
        }
        .environmentObject(profile_metadata)
    }

}

struct ProfilePicture: View {
    
    @ObservedObject var profile_metadata: ProfileMetadata
    
    var body: some View {
        // used apple documentation for photo-picker
        PhotosPicker(
            selection: Binding(
                get: { [] },
                set: { selectedItem in
                    Task {
                        // Load image data from the selected item
                        if let data = try? await selectedItem.first!.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            
                            // change image in UI instantly
                            await MainActor.run {
                                profile_metadata.temporaryProfilePicture = image
                            }
                            
                            // Upload the new profile picture
                            Task {
                                print("Uploading profile picture...")
                                let response = await profile_metadata.uploadProfilePicture(image)
                                
                                switch response {
                                case .success(let response):
                                    print("Uploaded profile picture: \(response)")
                                case .failure(let error):
                                    print("Failed to upload profile picture: \(error)")
                                }
                            }
                        } else {
                            print("Failed to load image & upload")
                        }
                    }
                }
            ),
            maxSelectionCount: 1,
            matching: .images,
            photoLibrary: .shared()
        ) {
            if let temp_profile_picture = profile_metadata.temporaryProfilePicture {
                Image(uiImage: temp_profile_picture)
                    .resizable()
                    .scaledToFill()
            } else {
                pictureAsyncFetch(
                    url: profile_metadata.profile_picture_url ?? profile_metadata.gravatar_url,
                    profile_picture: true
                )
            }
        }
        .buttonStyle(.plain)
    }
}

struct pictureAsyncFetch: View {
    
    var url: URL?
    var profile_picture: Bool? = false
    
    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            default:
                Image(systemName: "photo.fill")
                    .font(.system(size: 50))
                    .padding()
            }
        }
        .id(url)
    }
}

struct signOutToolBarItem: View {
    
    @EnvironmentObject private var viewParameters: ViewParameters
    
    var body: some View {
        Button {
            Task {
                await signOut()
                viewParameters.currentRoot = .landing
            }
        } label: {
            Text("Sign Out")
                .bold()
                .foregroundStyle(.red)
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

struct AllowPublicCollectionToggle: View {
    
    @ObservedObject var profile_metadata: ProfileMetadata
    
    var body: some View {
        HStack {
            Text("Show other users your collection?")
                .multilineTextAlignment(.leading)
                .bold()
                .foregroundStyle(.white)
            Toggle(isOn: $profile_metadata.public_collection) {
                
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 8)
                .foregroundStyle(.background.secondary)
        }
        
        .onChange(of: profile_metadata.public_collection) {
            Task {
                await profile_metadata.updateProfileMetadata(public_collection: profile_metadata.public_collection)
            }
        }
    }
}

struct AllowPublicListeningHistory: View {
    
    @ObservedObject var profile_metadata: ProfileMetadata
    
    var body: some View {
        HStack {
            Text("Show other users to your listening statistics?")
                .multilineTextAlignment(.leading)
                .bold()
                .foregroundStyle(.white)
            Toggle(isOn: $profile_metadata.public_statistics) {
                
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 8)
                .foregroundStyle(.background.secondary)
        }
        
        .onChange(of: profile_metadata.public_statistics) {
            Task {
                await profile_metadata.updateProfileMetadata(public_statistics: profile_metadata.public_statistics)
            }
        }
    }
}

#Preview {
    Profile()
}

