//
//  CameraView.swift
//  find-my-items
//
//  Created by Quang Tran Minh on 11/3/25.
//

import SwiftUI
import AVFoundation

/// The main camera view that combines camera preview, permissions, and search UI
struct CameraView: View {
    /// The camera view model
    @StateObject private var viewModel = CameraViewModel()
    
    /// Current search query
    @State private var currentQuery: String = ""
    
    /// Whether the app is currently in search mode
    @State private var isSearching: Bool = false
    
    /// The size of the view for overlay calculations
    @State private var viewSize: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Camera layer
                if viewModel.permissionStatus == .authorized {
                    CameraPreview(cameraManager: viewModel.cameraManager)
                        .edgesIgnoringSafeArea(.all)
                        .onAppear {
                            viewModel.startCamera()
                            // Store view size for overlay calculations
                            viewSize = geometry.size
                        }
                        .onDisappear {
                            viewModel.stopCamera()
                        }
                    
                    // Detection overlay (when in search mode)
                    if isSearching && !viewModel.matchingObjects.isEmpty {
                        DetectionOverlayView(
                            detectedObjects: viewModel.matchingObjects,
                            viewSize: viewSize
                        )
                    }
                    
                    // Search overlay
                    SearchOverlayView(
                        onSearch: { query in
                            self.currentQuery = query
                            self.isSearching = true
                            
                            // Trigger object detection with the search query
                            viewModel.setSearchQuery(query)
                        },
                        onFlashlightTap: {
                            viewModel.toggleFlashlight()
                        },
                        isFlashlightOn: viewModel.isFlashlightOn
                    )
                    
                    // Search mode indicator
                    if isSearching {
                        VStack {
                            Spacer()
                            
                            HStack {
                                Text("Looking for")
                                    .foregroundColor(.white)
                                
                                Text("\"\(currentQuery)\"")
                                    .foregroundColor(.white)
                                    .fontWeight(.bold)
                                
                                Spacer()
                                
                                Button(action: {
                                    self.isSearching = false
                                    self.currentQuery = ""
                                    
                                    // Stop object detection
                                    viewModel.clearSearchQuery()
                                }) {
                                    Text("Cancel")
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(Color.red.opacity(0.8))
                                        .cornerRadius(8)
                                }
                            }
                            .padding()
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(10)
                            .padding(.horizontal)
                            .padding(.bottom, 150) // Position above the search UI
                        }
                    }
                    
                    // Detection status message
                    if isSearching && viewModel.matchingObjects.isEmpty && viewModel.isDetectionActive {
                        VStack {
                            Text("Searching...")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(10)
                            
                            Spacer()
                        }
                        .padding(.top, 100)
                    }
                    
                    // Detection error message
                    if let errorMessage = viewModel.detectionError {
                        VStack {
                            Text("Detection Error: \(errorMessage)")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.red.opacity(0.8))
                                .cornerRadius(10)
                            
                            Spacer()
                        }
                        .padding(.top, 100)
                    }
                    
                    // Error message if any
                    if let errorMessage = viewModel.errorMessage {
                        VStack {
                            Text(errorMessage)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.red.opacity(0.8))
                                .cornerRadius(10)
                                .padding()
                            
                            Spacer()
                        }
                    }
                } else {
                    // Show permission request view if not authorized
                    CameraPermissionView(viewModel: viewModel)
                }
            }
            .onAppear {
                // Request camera permissions when view appears
                viewModel.requestCameraPermissionIfNeeded()
            }
        }
    }
} 