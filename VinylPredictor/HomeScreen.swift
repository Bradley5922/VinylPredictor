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
                            Label("Order", systemImage: "square.and.pencil")
                        }
                }
                
            }
            .toolbar {
                // the tool bar item views are written in the relevant view file
                switch selectedTab { // changing tool bar based on page
                case .main:
                    EmptyView()
                case .profile:
                    signOutToolBarItem()
                }
            }
        }
    }
}

#Preview {
    HomeScreen()
}
