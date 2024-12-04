//
//  HelperFunctionsSupabase.swift
//  VinylPredictor
//
//  Created by Bradley Cable on 28/10/2024.
//

import Foundation
import Supabase

struct CollectionItem: Codable {
    var user_id: UUID
    var discogs_id: Int
}

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
    let topArtists: [ItemListeningStats]
    let topAlbums: [ItemListeningStats]
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
