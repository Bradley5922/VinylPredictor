//
//  HelpperFunctions.swift
//  BurnFM-iOS (from another app of mine)
//
//  Created by Bradley Cable on 22/09/2024.
//  Amended on 27/10/2024

import SwiftyJSON
import Foundation

func getJSONfromURL(URL_string: String) async -> Result<JSON, Error> {
    
    guard let url = URL(string: URL_string) else {
        return .failure(NSError(domain: "Invalid URL", code: 0))
    }
    
    do {
        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSON(data: data)
        return .success(json)
    } catch {
        return .failure(error)
    }
}


