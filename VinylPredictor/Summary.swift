//
//  Summary.swift
//  VinylPredictor
//
//  Created by Bradley Cable on 03/11/2024.
//

import SwiftUI

struct Summary: View {
    
    @State var exampleOne: Album?
    @State var exampleTwo: Album?
    
    var body: some View {
        VStack {
            HStack(alignment: .top) {
                if exampleOne == nil || exampleTwo == nil {
                    VStack {
                        Spacer()
                        ProgressView().scaleEffect(2)
                        Spacer()
                    }
                } else {
                    VStack {
                        TopAlbumBox(album: exampleOne!)
                        TotalCollection()
                        RecommendationPageLink()
                    }
                    VStack {
                        TotalListening()
                        LowAlbumBox(album: exampleTwo!)
                        FavouriteGenreBox()
                    }
                }
            }
            
            Spacer()
        }
        .navigationTitle("Summary")
        .padding()
        
        .onAppear() {
            Task {
                do {
                    exampleOne = try await discogsFetch(id: 3455408).get()
                    exampleTwo = try await discogsFetch(id: 24047).get()
                } catch {
                    
                }
            }
        }
    }
}

#Preview {
    Summary()
}

struct TopAlbumBox: View {
    
    let album: Album
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .foregroundStyle(.background.secondary)
            .frame(maxWidth: .infinity, maxHeight: 250)
        
            .overlay {
                VStack {
                    Text("Top Album")
                        .font(.title2)
                        .bold()
                    
                    Spacer()
                    
                    album.image
                        .frame(width: 110, height: 110)
                        .overlay {
                            ZStack {
                                Rectangle()
                                    .foregroundStyle(.background.tertiary)
                                    .opacity(0.5)
                                
                                VStack {
                                    Text("10")
                                        .bold()
                                        .font(.largeTitle)
                                    Text("Hours")
                                        .fontWeight(.light)
                                }
                                
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    Spacer()
                    
                    Text("Silence is Loud")
                        .font(.headline)
                    Text("Nia Archives")
                        .font(.subheadline)
                }
                .padding()
                
            }
    }
}

struct LowAlbumBox: View {
    
    let album: Album
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .foregroundStyle(.background.secondary)
            .frame(maxWidth: .infinity, maxHeight: 250)
        
            .overlay {
                VStack {
                    Text("Unloved 💔")
                        .font(.title2)
                        .bold()
                    
                    Spacer()
                    
                    album.image
                        .frame(width: 110, height: 110)
                        .overlay {
                            ZStack {
                                Rectangle()
                                    .foregroundStyle(.background.tertiary)
                                    .opacity(0.5)
                                
                                VStack {
                                    Text("Listened to the least")
                                        .multilineTextAlignment(.center)
                                        .italic()
                                }
                                
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    Spacer()
                    
                    Text("Abbey Road")
                        .font(.headline)
                    Text("The Beatles")
                        .font(.subheadline)
                }
                .padding()
                
            }
    }
}

struct TotalListening: View {
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .foregroundStyle(.background.secondary)
            .frame(maxWidth: .infinity, maxHeight: 175)
        
            .overlay {
                VStack {
                    Text("Total Time")
                        .font(.title2)
                        .bold()
                    
                    Spacer()
                    
                    VStack(alignment: .leading) {
                        Text("50 Hours")
                            .font(.title2)
                            .bold()
                        Text("20 Minutes")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .fontWeight(.light)
                        Text("15 Seconds")
                            .font(.headline)
                            .fontWeight(.ultraLight)
                    }
                    
                    Spacer()
                }
                .padding()
                
            }
    }
}

struct FavouriteGenreBox: View {
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .foregroundStyle(.background.secondary)
            .frame(maxWidth: .infinity, maxHeight: 130)
        
            .overlay {
                VStack {
                    Text("Top Genre")
                        .font(.title2)
                        .bold()
                    
                    Spacer()
                    
                    VStack {
                        Text("Rock")
                            .font(.title3)
                            .bold()
                        Text("30% of total listening")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fontWeight(.light)
                    }
                    
                    Spacer()
                }
                .padding()
            }
    }
}

struct RecommendationPageLink: View {
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .foregroundStyle(.background.secondary)
            .frame(maxWidth: .infinity, maxHeight: 175)
        
            .overlay {
                VStack {
                    Text("What's New")
                        .font(.title2)
                        .bold()
                    
                    Spacer()
                    
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 45))
                        .foregroundStyle(.yellow)
                    
                    Spacer()
                    
                    Text("Tap to for album recommendations!")
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
    }
}

struct TotalCollection: View {
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .foregroundStyle(.background.secondary)
            .frame(maxWidth: .infinity, maxHeight: 130)
        
            .overlay {
                VStack {
                    Text("Collection")
                        .font(.title2)
                        .bold()
                    
                    Spacer()
                    
                    VStack {
                        Text("25 Vinyls")
                            .font(.title2)
                        Text("w/ 15 distinct artists")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fontWeight(.light)
                    }
                    
                    Spacer()
                }
                .padding()
            }
    }
}
