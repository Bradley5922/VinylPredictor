//
//  HomeScreen.swift
//  VinylPredictor
//
//  Created by Bradley Cable on 26/10/2024.
//

import SwiftUI
import Supabase

enum SelectedTab {
    case collection
    case summary
    case profile
}

struct HomeScreen: View {
    
    @EnvironmentObject private var viewParameters: ViewParameters
    
    @State private var selectedTab: SelectedTab = .collection
    
    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                CollectionView()
                    .tag(SelectedTab.collection)
                    .tabItem {
                        Label("Collection", systemImage: "square.stack.3d.up.fill")
                    }
                
                Summary()
                    .tag(SelectedTab.summary)
                    .tabItem {
                        Label("Summary", systemImage: "list.bullet.rectangle.fill")
                    }
                
                Profile()
                    .tag(SelectedTab.profile)
                    .tabItem {
                        Label("Profile", systemImage: "person.fill")
                    }
            }
        }
    }
}

#Preview {
    HomeScreen()
}
