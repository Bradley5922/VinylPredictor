//
//  Profile.swift
//  VinylPredictor
//
//  Created by Bradley Cable on 27/10/2024.
//

import SwiftUI
import _PhotosUI_SwiftUI
import Auth

struct Profile: View {
    
    @StateObject var profile_metadata: ProfileMetadata = ProfileMetadata()
    
    @State private var editTextAlertShowing = false
    @State private var editedName = ""

    var body: some View {
        NavigationView {
            VStack {
                if let _ = profile_metadata.user_id { // Updated from user_id
                    
                    ProfilePicture(profile_metadata: profile_metadata)
                        .frame(width: 175, height: 175)
                        .background(Color.gray)
                        .clipShape(Circle())
                    
                    Button {
                        editTextAlertShowing.toggle()
                    } label: {
                        HStack(alignment: .center) {
                            Text(profile_metadata.display_name) // Updated from display_name
                                .font(.title)
                                .bold()
                            
                            Image(systemName: "square.and.pencil")
                                .foregroundStyle(.secondary)
                                .bold()
                        }
                        .foregroundStyle(.white)
                    }
                    .alert("Enter your name", isPresented: $editTextAlertShowing) {
                        TextField("Enter your name", text: $editedName)
                        Button("Update") {
                            Task {
                                await profile_metadata.updateProfileMetadata(displayName: editedName) // Updated parameter
                            }
                        }
                    } message: {
                        Text("This is the name that will be displayed to other users.")
                    }
                    
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
//            .task {
//                // Use .task instead of onAppear for SwiftUI concurrency
//                await $profile_metadata.fetch
//            }
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
            .ignoresSafeArea(.keyboard)
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
                            
                            // Change image in UI instantly
                            await MainActor.run {
                                profile_metadata.temp_profile_picture = image
                            }
                            
                            // Upload the new profile picture
                            Task {
                                print("Uploading profile picture...")
                                let response = await profile_metadata.uploadProfilePicture(image)
                                
                                switch response {
                                case .success:
                                    print("Uploaded profile picture successfully.")
                                case .failure(let error):
                                    print("Failed to upload profile picture: \(error.localizedDescription)")
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
            if let temp_profile_picture = profile_metadata.temp_profile_picture {
                Image(uiImage: temp_profile_picture)
                    .resizable()
                    .scaledToFill()
            } else {
                pictureAsyncFetch(
                    localImage: profile_metadata.profile_picture,
                    url: profile_metadata.gravatarURL,
                    profile_picture: true
                )
            }
        }
        .buttonStyle(.plain)
    }
}


struct pictureAsyncFetch: View {
    var localImage: Image? // Optional image that can be passed
    
    var url: URL?
    var profile_picture: Bool? = false
    
    var body: some View {
        Group {
            if let localImage = localImage { // If a local image is provided
                localImage
                    .resizable()
                    .scaledToFill()
            } else if let url = url { // If no local image, fallback to AsyncImage
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
                .id(url) // Ensures updates when URL changes
            } else {
                Image(systemName: "photo.fill")
                    .font(.system(size: 50))
                    .padding()
            }
        }
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
    
    // 'async' allows this function to run without blocking other code.
    // 'await' pauses execution of this function until the sign-out operation completes.
    func signOut() async {
        do {
            try await supabase.auth.signOut() 
            print("Sign Out Complete") // Runs after successful sign out
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
            Toggle(isOn: $profile_metadata.public_collection) { // Updated property name
                
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 8)
                .foregroundStyle(.background.secondary)
        }
        
        .onChange(of: profile_metadata.public_collection) { // Updated property name
            Task {
                await profile_metadata.updateProfileMetadata(publicCollection: profile_metadata.public_collection) // Updated parameter
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
            Toggle(isOn: $profile_metadata.public_statistics) { // Updated property name
                
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 8)
                .foregroundStyle(.background.secondary)
        }
        
        .onChange(of: profile_metadata.public_statistics) { // Updated property name
            Task {
                await profile_metadata.updateProfileMetadata(publicStatistics: profile_metadata.public_statistics) // Updated parameter
            }
        }
    }
}

//#Preview {
//    @Previewable var profile_metadata: ProfileMetadata = ProfileMetadata()
//
//    Profile(profile_metadata: profile_metadata)
//        .onAppear() {
//            profile_metadata.userID = UUID(uuidString: "fa7a8e5c-488b-4f45-b11e-0b52bdf42b4b")!
//        }
//}
