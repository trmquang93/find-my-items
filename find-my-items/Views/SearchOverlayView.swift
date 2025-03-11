//
//  SearchOverlayView.swift
//  find-my-items
//
//  Created by Quang Tran Minh on 11/3/25.
//

import SwiftUI
import Combine

/// A view that displays a search overlay on top of the camera feed
struct SearchOverlayView: View {
    /// The search text entered by the user
    @State private var searchText: String = ""
    
    /// Whether the keyboard is currently shown
    @State private var isKeyboardShown: Bool = false
    
    /// Action to perform when search is submitted
    var onSearch: (String) -> Void
    
    /// Action to perform when flashlight button is tapped
    var onFlashlightTap: () -> Void
    
    /// Whether the flashlight is currently on
    var isFlashlightOn: Bool
    
    /// Initialize with search and flashlight actions
    init(
        onSearch: @escaping (String) -> Void,
        onFlashlightTap: @escaping () -> Void,
        isFlashlightOn: Bool = false
    ) {
        self.onSearch = onSearch
        self.onFlashlightTap = onFlashlightTap
        self.isFlashlightOn = isFlashlightOn
    }
    
    var body: some View {
        VStack {
            // Top controls
            HStack {
                // App title
                Text("Find My Items")
                    .font(.headline)
                    .foregroundColor(.white)
                    .shadow(radius: 2)
                
                Spacer()
                
                // Flashlight button
                Button(action: onFlashlightTap) {
                    Image(systemName: isFlashlightOn ? "flashlight.on.fill" : "flashlight.off.fill")
                        .font(.system(size: 22))
                        .foregroundColor(isFlashlightOn ? .yellow : .white)
                        .padding(10)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            
            Spacer()
            
            // Search UI at the bottom
            VStack(spacing: 16) {
                // Search text field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .padding(.leading, 10)
                    
                    TextField("What are you looking for?", text: $searchText)
                        .padding(10)
                        .foregroundColor(.black)
                        .onSubmit {
                            if !searchText.isEmpty {
                                onSearch(searchText)
                            }
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .padding(.trailing, 10)
                        }
                    }
                }
                .background(Color.white.opacity(0.9))
                .cornerRadius(10)
                .shadow(radius: 3)
                
                // Search button
                Button(action: {
                    if !searchText.isEmpty {
                        onSearch(searchText)
                        // Dismiss keyboard
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }) {
                    Text("Find Item")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(searchText.isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(10)
                        .shadow(radius: 3)
                }
                .disabled(searchText.isEmpty)
            }
            .padding()
            .background(Color.black.opacity(0.4))
            .cornerRadius(16)
            .padding([.horizontal, .bottom])
        }
    }
} 
