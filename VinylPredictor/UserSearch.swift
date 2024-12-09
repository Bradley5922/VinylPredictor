//
//  UserSearch.swift
//  VinylPredictor
//
//  Created by Bradley Cable on 08/12/2024.
//

import SwiftUI

struct UserSearch: View {
    
    @State var searchText: String = ""
    
    @State var results: [ProfileMetadataModel] = []
    
    var body: some View {
        
        List {
            if results.isEmpty && !searchText.isEmpty {
                Text("No results")
                    .foregroundStyle(.secondary)
                    .font(.title)
                    .fontWeight(.light)
                    .italic()
            } else if results.isEmpty && searchText.isEmpty {
                Text("Use the search above to find users")
                    .foregroundStyle(.secondary)
                    .font(.title)
                    .fontWeight(.light)
                    .italic()
            } else {
                ForEach(results) { result in
                    NavigationLink(destination: Text("hello, world")) {
                        HStack(spacing: 15) {
                            profilePictureAsyncFetch(url: result.profile_picture_url)
                                .frame(width: 80, height: 80)
                                .background(Color.gray)
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading) {
                                Text(result.email)
                                    .font(.headline)
                                    .bold()
                                
                                Text("Lorem ipsum dolor sit amet, consectetur adipiscing elit.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .italic()
                            }
                        }
                    }
                }
            }
            
        }
        .onChange(of: searchText) {
            Task {
                let fetch = await searchProfiles(searchTerm: searchText)
                
                switch fetch {
                case .success(let profiles):
                    results = profiles
                case .failure(let error):
                    print(error)
                    results = []
                }
            }
        }
        
        .searchable(text: $searchText)
        .navigationTitle("User Search")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    UserSearch()
}
