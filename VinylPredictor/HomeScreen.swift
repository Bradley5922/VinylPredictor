//
//  HomeScreen.swift
//  VinylPredictor
//
//  Created by Bradley Cable on 26/10/2024.
//

import SwiftUI
import Supabase

enum SelectedTab {
    case main
    case profile
}

struct HomeScreen: View {
    
    @EnvironmentObject private var rootViewSelector: RootViewSelector
    @State private var selectedTab: SelectedTab = .main
    
    var body: some View {
        
        NavigationView() {
            VStack {
                
                TabView(selection: $selectedTab) {
                    MainScreen()
                        .tag(SelectedTab.main)
                    
                        .tabItem {
                            Label("Menu", systemImage: "list.dash")
                        }

                    Profile()
                        .tag(SelectedTab.profile)
                    
                        .tabItem {
                            Label("Profile", systemImage: "person.fill")
                        }
                }
                
            }
            .toolbar {
                if selectedTab == .profile {
                    // the tool bar item views are written in the relevant view file
                    signOutToolBarItem()
                }
            }
        }
    }
}

#Preview {
    HomeScreen()
}
