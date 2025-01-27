//
//  HelperFunctionsSupabase.swift
//  VinylPredictor
//
//  Created by Bradley Cable on 28/10/2024.
//

import Foundation
import Supabase
import SwiftUI
import PhotosUI
import CryptoKit
import MusicKit

//struct ListeningAnalytics: Codable {
//    var id: UUID
//    var user_id: String
//    var album_name: String
//    var artist_name: String
//    var listening_hours: Int
//}
//
//struct ItemListeningStats: Codable, Identifiable {
//    var id: UUID {
//        UUID() // Generate a unique ID for use in SwiftUI Lists\
//    }
//    
//    let name: String
//    let total_listening_mins: Int
//}
//
//struct TopListeningStats {
//    let overall: Int
//    let topArtists: [ItemListeningStats]
//    let topAlbums: [ItemListeningStats]
//}
//
//func fetchOverallListeningTime(user_id: UUID) async -> Result<Int, Error> {
//    do {
//
//        // Fetch data via database function
//        let totalTime: Int = try await supabase
//            .rpc("get_total_listening_time", params: ["user_id_input": user_id])
//            .execute()
//            .value
//
//        return .success(totalTime)
//    } catch {
//        return .failure(error)
//    }
//}
//
//func fetchTopArtists(user_id: UUID) async -> Result<[ItemListeningStats], Error> {
//    do {
//
//        // Fetch data via database function
//        let topArtists: [ItemListeningStats] = try await supabase
//            .rpc("get_top_artists", params: ["user_id_input": user_id])
//            .execute()
//            .value
//
//        return .success(topArtists)
//    } catch {
//        return .failure(error)
//    }
//}


//func fetchTopAlbums(user_id: UUID) async -> Result<[ItemListeningStats], Error> {
//    do {
//
//        // Fetch data via database function
//        let topAlbums: [ItemListeningStats] = try await supabase
//            .rpc("get_top_albums", params: ["user_id_input": user_id])
//            .execute()
//            .value
//
//        return .success(topAlbums)
//    } catch {
//        return .failure(error)
//    }
//}
//
//func fetchUserListeningStats(passed_user_id: UUID? = nil) async -> Result<TopListeningStats, Error> {
//    do {
//        var user_id: UUID
//        
//        if let passed_user_id = passed_user_id {
//            user_id = passed_user_id
//        } else {
//            // probably wanting current user profile
//            user_id = try await supabase.auth.session.user.id
//        }
//        
//        let temp = await TopListeningStats(
//            overall: try fetchOverallListeningTime(user_id: user_id).get(),
//            topArtists: try fetchTopArtists(user_id: user_id).get(),
//            topAlbums: try fetchTopAlbums(user_id: user_id).get()
//        )
//        
//        return .success(temp)
//    } catch {
//        return .failure(error)
//    }
//}

struct CollectionItem: Codable {
    var user_id: UUID
    var discogs_id: Int
    var listened_to_seconds: Int?
}

func updateListeningHistory(for album: Album, listening_time_seconds: TimeInterval) async -> Result<CollectionItem, Error> {
    do {
        let user_id = try await supabase.auth.session.user.id
        
        // Fetch the current value of listened_to_seconds
        let currentListeningTime: CollectionItem = try await supabase
            .from("collection")
            .select()
            .eq("user_id", value: user_id)
            .eq("discogs_id", value: album.id)
            .single()
            .execute()
            .value
        
        let updated_listening_time = (currentListeningTime.listened_to_seconds ?? 0) + Int(listening_time_seconds.rounded())

        // Update the listened_to_seconds value in the database
        let updated: CollectionItem = try await supabase
            .from("collection")
            .update([
                "listened_to_seconds": updated_listening_time
            ])
            .eq("user_id", value: user_id)
            .eq("discogs_id", value: album.id)
            .select()
            .single()
            .execute()
            .value

        return .success(updated)
    } catch {
        return .failure(error)
    }
}


func addToCollection(album: Album) async -> Result<CollectionItem?, Error> {
    do {
        let user_id = try await supabase.auth.session.user.id
        
        let collectionItem = CollectionItem(
            user_id: user_id,
            discogs_id: album.id
        )
        
        let returned_from_db: CollectionItem = try await supabase
            .from("collection")
            .insert(collectionItem)
            .select()
            .single() // single value returned after insert
            .execute()
            .value
        
        return .success(returned_from_db)
    } catch {
        return .failure(error)
    }

}

func removeFromCollection(discogs_id: Int) async -> Result<CollectionItem?, Error> {
    do {
        let user_id = try await supabase.auth.session.user.id
        
        try await supabase
            .from("collection")
            .delete()
            .eq("user_id", value: user_id)
            .eq("discogs_id", value: discogs_id)
            .execute()
        
        return .success(nil)
    } catch {
        return .failure(error)
    }
}

func fetchCollection(
    passed_user_id: UUID? = nil,
    searched_user_collection: AlbumCollectionModel? = nil
    )
    -> AsyncThrowingStream<(Album, Int), Error> {
    
    let fetchID = UUID() // Unique identifier for each call
    print("fetchCollection called: \(fetchID)")
    
    return AsyncThrowingStream { continuation in
        Task {
            do {
                // Determine the user ID, use passed_user_id or the current user's ID
                let user_id: UUID
                
                if let passed_user_id = passed_user_id {
                    user_id = passed_user_id
                } else {
                    // Fetch the current user ID from the session
                    user_id = try await supabase.auth.session.user.id
                }
                
                // Fetch collection items from the database
                let collectionItems: [CollectionItem] = try await supabase
                    .from("collection")
                    .select()
                    .eq("user_id", value: user_id)
                    .execute()
                    .value
                
                // Iterate through collection items and fetch album details
                for item in collectionItems {
                    
                    // Check for task cancellation
                    if Task.isCancelled {
                        print("Task was cancelled during collection item processing.")
                        continuation.finish()
                        return
                    }
                    
                    // Fetch album details from Discogs
                    let result = await discogsFetch(id: item.discogs_id)
                    
                    switch result {
                    case .success(let album):
                        // Check for cancellation again before yielding
                        if Task.isCancelled {
                            print("Task was cancelled during album fetch.")
                            continuation.finish()
                            return
                        }
                        
                        let listenedSeconds = item.listened_to_seconds ?? 0
                        continuation.yield((album, listenedSeconds))
                        print("Successfully fetched album: \(album.title)")
                        
                    case .failure(let error):
                        // Log the error, and proceed to the next album
                        print("Failed to fetch album for ID \(item.discogs_id): \(error.localizedDescription)")
                    }
                }
                
                // Signal that the stream has finished
                continuation.finish()
            } catch {
                // If an error occurs, finish the stream with the error
                if Task.isCancelled {
                    print("Task was cancelled during error handling.")
                } else {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: User Recommendations

struct UserRecommendations: Codable {
    var user_id: UUID
    var updated_at: String
    
    var recommendations: [Int]
}

func fetchRecommendations() async -> Result<UserRecommendations, Error> {
    do {
        var user_id: UUID
        user_id = try await supabase.auth.session.user.id
        
        let recommendationsArray: [UserRecommendations] = try await supabase
            .from("user_matrices")
            .select()
            .eq("user_id", value: user_id)
            .execute()
            .value
        
        print(recommendationsArray)

        // Handle the case where no recommendations exist for some reason
        guard let recommendations = recommendationsArray.first, !recommendations.recommendations.isEmpty else {
            return .failure(NSError(domain: "No recommendations found for the user", code: 404, userInfo: nil))
        }

        return .success(recommendations)
    } catch {
        return .failure(error)
    }
}

func call_recommendations_edge_function() async {
    
    do {
        let user_id = try await supabase.auth.session.user.id
        
        let _ = try await supabase.functions
            .invoke(
                "recalculate-user-matrix",
                options: FunctionInvokeOptions(
                    headers: [
                        "x-user-id": user_id.uuidString
                    ]
                )
            )
    } catch {
        print(error)
    }
}

func fetchStarredAlbums() async -> [Int] {
    do {
        let user_id = supabase.auth.currentUser?.id
        
        let fetchedAlbums: [String: [Int]] = try await supabase
            .from("user_matrices")
            .select("starred_recs")
            .eq("user_id", value: user_id)
            .single()
            .execute()
            .value

        return fetchedAlbums["starred_recs"] ?? []
    } catch {
        print("Failed to fetch starred albums: \(error)")
    }
    
    return []
}


// MARK: User Profile
class ProfileMetadata: ObservableObject, Identifiable, Codable, Hashable {
    
    static func == (lhs: ProfileMetadata, rhs: ProfileMetadata) -> Bool {
        return lhs.user_id == rhs.user_id // Compare based on the unique user ID
    }
    func hash(into hasher: inout Hasher) {
           hasher.combine(user_id) // Use the unique user ID for hashing
    }
    
    // MARK: - Properties
    @Published var user_id: UUID?
    @Published var email: String?
    @Published var display_name: String = "Display Name"
    
    @Published var public_collection: Bool = false
    @Published var public_statistics: Bool = false
    
    @Published var starred_users: [UUID] = []
    
    @Published var profile_picture: Image?
    /// used when updating the profile picture, as not to upload and download the file on change
    @Published var temp_profile_picture: UIImage?
    
    /// Computed Gravatar URL based on the user's email.
    var gravatarURL: URL {
        let trimmedEmail = (email ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        guard let emailData = trimmedEmail.data(using: .utf8) else {
            return URL(string: "https://www.gravatar.com/avatar/?s=800&d=robohash&r=x")!
        }
        
        let hashed = SHA256.hash(data: emailData).compactMap { String(format: "%02x", $0) }.joined()
        
        return URL(string: "https://www.gravatar.com/avatar/\(hashed)?s=800&d=robohash&r=x")!
    }
    
    /// Conformance to `Identifiable` protocol.
    var id: UUID? { user_id }
    
    // MARK: - Initialiser
    
    /// Default initialiser that fetches user data internally.
    init() {
        Task {
            await fetchInitialData()
        }
    }
    
    // MARK: - Make it Codable
    
    /// Defines the keys (which are also in the db) used for encoding and decoding.
    /// Excludes `profilePictureURL` as it's generated, not stored in the database.
    enum CodingKeys: String, CodingKey {
        case user_id
        case email
        case display_name
        case public_collection
        case public_statistics
        case starred_users
    }
    
    /// Initialises a new instance by decoding (from data returned from Supabase)
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        user_id = try container.decodeIfPresent(UUID.self, forKey: .user_id)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        display_name = try container.decodeIfPresent(String.self, forKey: .display_name) ?? "Display Name"
        public_collection = try container.decodeIfPresent(Bool.self, forKey: .public_collection) ?? false
        public_statistics = try container.decodeIfPresent(Bool.self, forKey: .public_statistics) ?? false
        starred_users = try container.decodeIfPresent([UUID].self, forKey: .starred_users) ?? []
        // profilePictureURL is not decoded from data
        
        // Fetch the profile picture URL synchronously if userID is available
        if user_id != nil {
            let semaphore = DispatchSemaphore(value: 0)
            var fetchError: Error?
            
            // Create a Task to perform the asynchronous fetch as synchronous
            Task {
                do {
//                    try await fetchPictureURL()
                    await fetchPicture()
                } catch {
                    fetchError = error
                    print("Error fetching profile picture URL: \(error.localizedDescription)")
                }
                semaphore.signal()
            }
            
            // Wait for the fetch to complete
            semaphore.wait()
            
            // Throw error if fetching failed
            if let error = fetchError {
                throw error
            }
        }
    }
    
    /// Encodes this instance to be uploaded to Supabase when needed
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(user_id, forKey: .user_id)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encode(display_name, forKey: .display_name)
        try container.encode(public_collection, forKey: .public_collection)
        try container.encode(public_statistics, forKey: .public_statistics)
        try container.encode(starred_users, forKey: .starred_users)
    }
    
    // MARK: - Methods
    
    /// Fetches initial user data (userID and email) and then fetches profile metadata.
    private func fetchInitialData() async {
        do {
            let user = try await supabase.auth.session.user
            let fetchedUserID = user.id
            
            await MainActor.run {
                self.user_id = fetchedUserID
                self.email = user.email
            }
            
            // Now fetch the profile metadata
            let result = await fetchProfile()
            switch result {
            case .success:
                print("Profile metadata fetched successfully.")
            case .failure(let error):
                print("Failed to fetch profile metadata: \(error.localizedDescription)")
            }
        } catch {
            print("Error fetching initial user data: \(error.localizedDescription)")
        }
    }
    
    /// Fetches the public URL for the profile picture from Supabase Storage.
//    func fetchPictureURL() async throws {
//        guard let userID = user_id else { return }
//        
//        let filePath = "\(userID)"
//        let publicURL = try supabase.storage
//            .from("profile_pictures")
//            .getPublicURL(path: filePath)
//        
//        await MainActor.run {
//            self.profile_picture_URL = publicURL
//        }
//    }
    
    func fetchPicture() async {
        guard let user_id = user_id else { return }
        
        do {
            let data = try await supabase.storage
                .from("profile_pictures")
                .download(path: "\(user_id)")
            
            // Convert data to UIImage and then to SwiftUI Image
            if let uiImage = UIImage(data: data) {
                print("Downloaded Successfully")
                
                await MainActor.run {
                    self.profile_picture = Image(uiImage: uiImage)
                }
            } else {
                print("Failed to convert data to UIImage")
                self.profile_picture = nil
            }
        } catch {
            print("Error downloading image: \(error)")
            self.profile_picture = nil
        }
    }
    
    enum generalError: Error {
        case noUserID
    }
    
    /// Fetches or creates profile metadata from Supabase and updates properties.
    func fetchProfile() async -> Result<Void, Error> {
        guard let userID = user_id else {
            return .failure(generalError.noUserID)
        }
        
        do {
            let fetchedData: ProfileMetadata = try await supabase
                .from("user_metadata")
                .select()
                .eq("user_id", value: userID)
                .single()
                .execute()
                .value
            
            // Update properties with fetched data
            DispatchQueue.main.async {
                self.email = fetchedData.email
                self.display_name = fetchedData.display_name
                self.public_collection = fetchedData.public_collection
                self.public_statistics = fetchedData.public_statistics
                self.starred_users = fetchedData.starred_users
            }
            
            // Fetch the profile picture URL
            await fetchPicture()
            
            return .success(())
        } catch {
            print("Error fetching profile metadata: \(error.localizedDescription)")
            return .failure(error)
        }
    }
    
    /// Uploads a profile picture and updates the `profilePictureURL`.
    func uploadProfilePicture(_ image: UIImage) async -> Result<Void, Error> {
        guard let userID = user_id else {
            return .failure(generalError.noUserID)
        }
        
        do {
            
            let filePath = userID.uuidString
            _ = try await supabase.storage
                .from("profile_pictures")
                .upload(
                    filePath,
                    data: image.jpegData(compressionQuality: 0.8)!,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: "image/jpeg",
                        upsert: true
                    )
                )
            
            await fetchPicture()
            return .success(())
        } catch {
            print("Failed to upload profile picture: \(error.localizedDescription)")
            return .failure(error)
        }
    }
    
    /// Updates the profile metadata in Supabase, only updates what is provided
    ///   - publicCollection: Optional new value for `publicCollection`.
    ///   - publicStatistics: Optional new value for `publicStatistics`.
    ///   - singularStarredProfile: Optional user ID to add or remove from `starredUsers`.
    ///   - displayName: Optional new value for `displayName`.
    func updateProfileMetadata(
        publicCollection: Bool? = nil,
        publicStatistics: Bool? = nil,
        singularStarredProfile: UUID? = nil,
        displayName: String? = nil
    ) async -> Result<Void, Error> {
        guard let userID = user_id else {
            return .failure(generalError.noUserID)
        }
        
        do {
            var updatedStarredUsers = starred_users
            
            if let singularStarredProfile = singularStarredProfile {
                if let index = updatedStarredUsers.firstIndex(of: singularStarredProfile) {
                    updatedStarredUsers.remove(at: index)
                } else {
                    updatedStarredUsers.append(singularStarredProfile)
                }
            }
            
            let update = UpdateObject(
                public_collection: publicCollection ?? self.public_collection,
                public_statistics: publicStatistics ?? self.public_statistics,
                starred_users: updatedStarredUsers,
                display_name: displayName ?? self.display_name
            )
            
            let updatedMetadata: ProfileMetadata = try await supabase
                .from("user_metadata")
                .update(update)
                .eq("user_id", value: userID)
                .select()
                .single()
                .execute()
                .value
            
            // Update local properties with updated data
            DispatchQueue.main.async {
                self.email = updatedMetadata.email
                self.display_name = updatedMetadata.display_name
                self.public_collection = updatedMetadata.public_collection
                self.public_statistics = updatedMetadata.public_statistics
                self.starred_users = updatedMetadata.starred_users
            }
            
            return .success(())
        } catch {
            print("Updating metadata failed: \(error.localizedDescription)")
            return .failure(error)
        }
    }
    
    // MARK: - Supporting Structures
    
    /// Structure used to encode update data for profile metadata.
    private struct UpdateObject: Encodable {
        var public_collection: Bool
        var public_statistics: Bool
        var starred_users: [UUID]
        var display_name: String
        
        enum CodingKeys: String, CodingKey {
            case public_collection
            case public_statistics
            case starred_users
            case display_name
        }
    }
}


func fetchStaredProfiles() async -> Result<[ProfileMetadata], Error> {
    do {
        let current_user_id = try await supabase.auth.session.user.id

        // Fetch stared users (of the current user)
        let staredUserIDsResult: [String: [UUID]] = try await supabase
            .from("user_metadata")
            .select("starred_users")
            .eq("user_id", value: current_user_id)
            .single()
            .execute()
            .value
        
        // some reason returns a dict
        let staredUserIDs: [UUID] = staredUserIDsResult["starred_users"] ?? []

        // Get associated profile data from the stared user array 
        let profiles: [ProfileMetadata] = try await supabase
            .from("user_metadata")
            .select()
            .in("user_id", values: staredUserIDs)
            .execute()
            .value
        
        return .success(profiles)
    } catch {
        return .failure(error)
    }
}


func searchProfiles(searchTerm: String) async -> Result<[ProfileMetadata], Error> {
    do {
        let current_user_id = try await supabase.auth.session.user.id

        // `ilike` operator for case-insensitive matching
        let profiles: [ProfileMetadata] = try await supabase
            .from("user_metadata")
            .select()
            // search by email or display name
            .or("email.ilike.%\(searchTerm)%,display_name.ilike.%\(searchTerm)%")
            .neq("user_id", value: current_user_id) // Exclude current user
            .limit(10)
            .execute()
            .value
        
        return .success(profiles)
    } catch {
        print("Error during fuzzy email search: \(error)")
        return .failure(error)
    }
}

