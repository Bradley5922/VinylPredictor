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
