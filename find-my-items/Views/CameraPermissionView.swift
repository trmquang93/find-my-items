//
//  CameraPermissionView.swift
//  find-my-items
//
//  Created by Quang Tran Minh on 11/3/25.
//

import SwiftUI

/// A view that handles camera permission states
struct CameraPermissionView: View {
    /// The camera view model
    @ObservedObject var viewModel: CameraViewModel
    
    var body: some View {
        ZStack {
            // Background
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 24) {
                // App icon
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                
                // Title
                Text("Camera Access Required")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                // Description
                Text("Find My Items needs camera access to help you find your belongings. Please grant access to use all features.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal)
                
                // Action button
                if viewModel.permissionStatus == .notDetermined {
                    Button(action: {
                        viewModel.requestCameraPermissionIfNeeded()
                    }) {
                        Text("Grant Camera Access")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 16)
                } else if viewModel.permissionStatus == .denied || viewModel.permissionStatus == .restricted {
                    Button(action: {
                        viewModel.openSettings()
                    }) {
                        Text("Open Settings")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 16)
                    
                    Text("You can enable camera access in your device's settings.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding(.horizontal, 24)
        }
    }
} 