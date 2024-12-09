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

struct ListeningAnalytics: Codable {
    var id: UUID
    var user_id: String
    var album_name: String
    var artist_name: String
    var listening_hours: Int
}

struct ItemListeningStats: Codable, Identifiable {
    var id: UUID {
        UUID() // Generate a unique ID for use in SwiftUI Lists\
    }
    
    let name: String
    let total_listening_mins: Int
}

struct TopListeningStats {
    let overall: Int
    let topArtists: [ItemListeningStats]
    let topAlbums: [ItemListeningStats]
}

func fetchOverallListeningTime() async -> Result<Int, Error> {
    do {
        let user_id = try await supabase.auth.session.user.id.uuidString

        // Fetch data via database function
        let totalTime: Int = try await supabase
            .rpc("get_total_listening_time", params: ["user_id_input": user_id])
            .execute()
            .value

        return .success(totalTime)
    } catch {
        return .failure(error)
    }
}

func fetchTopArtists() async -> Result<[ItemListeningStats], Error> {
    do {
        let user_id = try await supabase.auth.session.user.id.uuidString

        // Fetch data via database function
        let topArtists: [ItemListeningStats] = try await supabase
            .rpc("get_top_artists", params: ["user_id_input": user_id])
            .execute()
            .value

        return .success(topArtists)
    } catch {
        return .failure(error)
    }
}

func fetchTopAlbums() async -> Result<[ItemListeningStats], Error> {
    do {
        let user_id = try await supabase.auth.session.user.id.uuidString

        // Fetch data via database function
        let topAlbums: [ItemListeningStats] = try await supabase
            .rpc("get_top_albums", params: ["user_id_input": user_id])
            .execute()
            .value

        return .success(topAlbums)
    } catch {
        return .failure(error)
    }
}

func fetchUserListeningStats() async -> Result<TopListeningStats, Error> {
    do {
        let temp = await TopListeningStats(
            overall: try fetchOverallListeningTime().get(),
            topArtists: try fetchTopArtists().get(),
            topAlbums: try fetchTopAlbums().get()
        )
        
        return .success(temp)
    } catch {
        return .failure(error)
    }
}

func updateListeningHistory(album_name: String, artist_name: String, listening_hours: Int) async -> Result<Any, Error> {
    do {
        let user_id = try await supabase.auth.session.user.id.uuidString

        // Query to check if a record already exists with similar (fuzzy search) album_name and artist_name
        // 'ilike' is used to "query data based on pattern-matching techniques"
        let existingRecords: [ListeningAnalytics] = try await supabase
            .from("listening_analytics")
            .select()
            .eq("user_id", value: user_id)
            .filter("album_name", operator: "ilike", value: "%\(album_name)%") // Use the SQL ilike operator as a string
            .filter("artist_name", operator: "ilike", value: "%\(artist_name)%") // Use the SQL ilike operator as a string
            .execute()
            .value

        if let existingRecord = existingRecords.first {
            // If a record exists, update the listening_hours
            try await supabase
                .from("listening_analytics")
                .update([
                    "listening_hours": existingRecord.listening_hours + listening_hours
                ])
                .eq("id", value: existingRecord.id)
                .execute()
        } else {
            // If no record exists, create a new one, with the passed listening hours
            try await supabase
                .from("listening_analytics")
                .insert([
                    "user_id": user_id,
                    "album_name": album_name,
                    "artist_name": artist_name,
                    "listening_hours": String(listening_hours)
                ])
                .execute()
        }

        return .success(true)
    } catch {
        return .failure(error)
    }
}

struct CollectionItem: Codable {
    var user_id: UUID
    var discogs_id: Int
}


func addToCollection(discogs_id: Int) async -> Result<Any, Error> {
    do {
        let user_id = try await supabase.auth.session.user.id
        
        let collectionItem = CollectionItem(user_id: user_id, discogs_id: discogs_id)
        
        let temp_item: CollectionItem = try await supabase
            .from("collection")
            .insert(collectionItem)
            .select()
            .single() // single value returned after insert
            .execute()
            .value
        
        return .success(temp_item)
    } catch {
        return .failure(error)
    }

}

func removeFromCollection(discogs_id: Int) async -> Result<Any, Error> {
    do {
        let user_id = try await supabase.auth.session.user.id
        
        try await supabase
            .from("collection")
            .delete()
            .eq("user_id", value: user_id)
            .eq("discogs_id", value: discogs_id)
            .execute()
        
        return .success(true)
    } catch {
        return .failure(error)
    }
}

func fetchCollection() async -> Result<[Album], Error> {
    do {
        let user_id = try await supabase.auth.session.user.id
        var collectionAlbums: [Album] = []
        
        let collectionItems: [CollectionItem] = try await supabase
            .from("collection")
            .select()
            .eq("user_id", value: user_id)
            .execute()
            .value
        
        for item in collectionItems {
            if case .success(let album) = await discogsFetch(id: item.discogs_id) {
                collectionAlbums.append(album)
            }
        }
        
        return .success(collectionAlbums)
    } catch {
        return .failure(error)
    }
}

// MARK: User Metadata

struct ProfileMetadataModel: Codable, Identifiable {
    let user_id: UUID
    let email: String
    
    let public_collection: Bool
    let public_statistics: Bool
    
    let profile_picture_url: URL?
    
    var id: UUID { // to conform to identifiable
        return user_id
    }
}

class ProfileMetadata: ObservableObject {
    @Published var user_id: UUID?
    @Published var email: String?
    
    @Published var public_collection: Bool = false
    @Published var public_statistics: Bool = false
    
    @Published var profile_picture_url: URL?
    @Published var temporaryProfilePicture: UIImage?

    // Fetch or create profile metadata
    func fetch() async {
        let result = await fetchProfileMetadata()
        await MainActor.run {
            switch result {
            case .success(let fetchedData):
                self.user_id = fetchedData.user_id
                self.email = fetchedData.email
                self.public_collection = fetchedData.public_collection
                self.public_statistics = fetchedData.public_statistics
                self.profile_picture_url = fetchedData.profile_picture_url
            case .failure(let error):
                print("Failed to fetch profile metadata: \(error)")
            }
        }
    }

    // Private function to fetch metadata
    private func fetchProfileMetadata() async -> Result<ProfileMetadataModel, Error> {
        do {
            
            // Check if `user_id` is already set within object; if not, fetch it
            let user_id: UUID
            
            if let existingUserID = self.user_id {
                user_id = existingUserID // will be set for user search
            } else {
                // probably for current user profile
                user_id = try await supabase.auth.session.user.id
            }

            
            // Try fetching existing profile metadata
            do {
                let fetchedData: ProfileMetadataModel = try await supabase
                    .from("profile_metadata")
                    .select()
                    .eq("user_id", value: user_id)
                    .single()
                    .execute()
                    .value

                // Update profile picture URL
                let updatedData = try await fetchPictureURL(for: fetchedData)
                return .success(updatedData)

            } catch let error as PostgrestError where error.code == "PGRST116" {
                
                print("Couldn't find profile metadata, creating new one")
                // No existing metadata found, create a new one
                let newProfile = await ProfileMetadataModel(
                    user_id: user_id,
                    email: try supabase.auth.session.user.email!,
                    public_collection: false,
                    public_statistics: false,
                    profile_picture_url: nil
                )

                let inserted = try await supabase
                    .from("profile_metadata")
                    .insert(newProfile)
                    .single()
                    .execute()
                

                let updated = try await fetchPictureURL(for: newProfile)
                
                if inserted.response.statusCode != 201 {
                    return .failure(PostgrestError(message: "Failed to insert new profile_metadata"))
                }
                
                return .success(updated)

            } catch {
                print("Couldn't fetch profile metadata: \(error)")
                return .failure(error)
            }
        } catch {
            print("Couldn't fetch profile metadata: \(error)")
            return .failure(error)
        }
    }

    private func fetchPictureURL(for profileMetadata: ProfileMetadataModel) async throws -> ProfileMetadataModel {
        
        let filePath = "\(profileMetadata.user_id)"
        let publicURL = try supabase.storage
            .from("profile_pictures")
            .getPublicURL(path: filePath)

        // Return updated model with the public URL
        return ProfileMetadataModel(
            user_id: profileMetadata.user_id,
            email: profileMetadata.email,
            public_collection: profileMetadata.public_collection,
            public_statistics: profileMetadata.public_statistics,
            profile_picture_url: publicURL
        )
    }

    // Upload a profile picture and update metadata
    func uploadProfilePicture(_ image: UIImage) async -> Result<Bool, Error> {
        do {
            let filePath = self.user_id!.uuidString // File name based on user ID

            // Upload or replace the file in storage
            _ = try await supabase.storage
                .from("profile_pictures")
                .upload(
                    filePath,
                    data: image.jpegData(compressionQuality: 1.0)!,
                    options: FileOptions(
                        cacheControl: "10",
                        contentType: "image/jpg",
                        upsert: true
                    )
                )

            return .success(true)
        } catch {
            return .failure(error)
        }
    }
    
    func updateProfileMetadata(public_collection: Bool? = nil, public_statistics: Bool? = nil) async -> Result<Bool, Error> {
        print("Updating profile metadata...")
        
        do {

            // Update the metadata in the database
            let updatedMetadata: ProfileMetadataModel = try await supabase
                .from("profile_metadata")
                .update([
                    // either use passed value or current value
                    "public_collection": public_collection ?? self.public_collection,
                    "public_statistics": public_statistics ?? self.public_statistics
                ])
                .eq(self.user_id!.uuidString, value: user_id)
                .select()
                .single()
                .execute()
                .value
            
            print(updatedMetadata)
            
            await MainActor.run {
                self.public_collection = updatedMetadata.public_collection
                self.public_statistics = updatedMetadata.public_statistics
            }

            return .success(true)
        } catch {
            return .failure(error)
        }
    }
    
}

func searchProfiles(searchTerm: String) async -> Result<[ProfileMetadataModel], Error> {
    do {
        let current_user_id = try await supabase.auth.session.user.id

        // `ilike` operator for case-insensitive matching
        let profiles: [ProfileMetadataModel] = try await supabase
            .from("profile_metadata")
            .select()
            .filter("email", operator: "ilike", value: "%\(searchTerm)%")
            .neq("user_id", value: current_user_id) // remove the current user from the list
            .execute()
            .value
        
        return .success(profiles)
    } catch {
        print("Error during fuzzy email search: \(error)")
        return .failure(error)
    }
}

