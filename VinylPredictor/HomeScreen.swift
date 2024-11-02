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
    case profile
}

struct HomeScreen: View {
    
    @EnvironmentObject private var rootViewSelector: RootViewSelector
    @State private var selectedTab: SelectedTab = .collection
    
    @State var isShowingBarcodeSheet: Bool = false
    
    
    var body: some View {
        
        NavigationView() {
            VStack {
                
                TabView(selection: $selectedTab) {
                    CollectionView(isShowingBarcodeSheet: $isShowingBarcodeSheet)
                        .tag(SelectedTab.collection)
                    
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
                // the tool bar item views are written in the relevant view file
                if selectedTab == .profile { signOutToolBarItem() }
                if selectedTab == .collection { BarcodeScannerToolBarItem(isShowingBarcodeSheet: $isShowingBarcodeSheet) }
            }
        }
    }
}

#Preview {
    HomeScreen()
}
