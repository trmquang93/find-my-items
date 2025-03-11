//
//  CameraViewModel.swift
//  find-my-items
//
//  Created by Quang Tran Minh on 11/3/25.
//

import Foundation
import AVFoundation
import Combine
import SwiftUI
import Vision

/// ViewModel for managing camera state and operations
class CameraViewModel: NSObject, ObservableObject {
    /// Camera manager instance
    @Published var cameraManager: CameraManager
    
    /// Whether the flashlight is currently on
    @Published var isFlashlightOn = false
    
    /// Current error message, if any
    @Published var errorMessage: String?
    
    /// Vision manager for object detection
    private var visionManager: VisionManager?
    
    /// Object matcher for text-based matching
    private var objectMatcher = ObjectMatcher()
    
    /// Current search parameters
    @Published var currentSearchParameters: SearchParameters?
    
    /// All detected objects from the latest frame
    @Published var detectedObjects: [RecognizedItem] = []
    
    /// Detected objects that match the current search query
    @Published var matchingObjects: [RecognizedItem] = []
    
    /// Whether object detection is currently active
    @Published var isDetectionActive = false
    
    /// Current detection error, if any
    @Published var detectionError: String?
    
    /// Counter for frame skipping (process every nth frame)
    private var frameCounter = 0
    
    /// Number of frames to skip between processing
    private var frameSkipCount = 5  // Process every 5th frame
    
    /// Whether the camera is currently running
    var isRunning: Bool {
        return cameraManager.isRunning
    }
    
    /// The current camera permission status
    var permissionStatus: CameraPermissionStatus {
        return cameraManager.permissionStatus
    }
    
    /// Private set of cancellables to store subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Initialize with a camera manager
    init(cameraManager: CameraManager = CameraManager()) {
        self.cameraManager = cameraManager
        super.init()
        
        // Initialize Vision Manager with model
        self.visionManager = VisionManager(modelName: "MobileNetV2")
        
        // Set self as delegate to receive video frames
        cameraManager.setVideoOutputDelegate(self)
        
        // Subscribe to permission changes
        cameraManager.$permissionStatus
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                if status == .denied || status == .restricted {
                    self?.errorMessage = "Camera access is required for this app to function. Please enable camera access in Settings."
                } else {
                    self?.errorMessage = nil
                }
            }
            .store(in: &cancellables)
    }
    
    /// Request camera permissions if not authorized
    func requestCameraPermissionIfNeeded() {
        if permissionStatus == .notDetermined {
            cameraManager.requestPermissions()
        }
    }
    
    /// Start the camera session
    func startCamera() {
        if permissionStatus == .authorized && !isRunning {
            cameraManager.startSession()
        }
    }
    
    /// Stop the camera session
    func stopCamera() {
        if isRunning {
            cameraManager.stopSession()
        }
    }
    
    /// Toggle the flashlight on/off
    func toggleFlashlight() {
        isFlashlightOn.toggle()
        cameraManager.toggleTorch(isOn: isFlashlightOn)
    }
    
    /// Open the system settings app
    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
    /// Set the current search query
    func setSearchQuery(_ query: String) {
        // Simple text processing to extract search parameters
        // In a more advanced implementation, this would use NLP techniques
        let targetItems = query.lowercased()
            .components(separatedBy: CharacterSet(charactersIn: " ,;"))
            .filter { !$0.isEmpty }
        
        currentSearchParameters = SearchParameters(targetItems: targetItems)
        
        // Start object detection
        isDetectionActive = true
        detectionError = nil
    }
    
    /// Clear the current search query
    func clearSearchQuery() {
        currentSearchParameters = nil
        matchingObjects = []
        isDetectionActive = false
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    /// Process video frames from the camera
    /// - Parameters:
    ///   - output: The output that produced the sample buffer
    ///   - sampleBuffer: The sample buffer containing the video frame
    ///   - connection: The connection from which the video frame came
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Skip frames when not in detection mode
        guard isDetectionActive else { return }
        
        // Skip frames for performance
        frameCounter += 1
        if frameCounter % frameSkipCount != 0 {
            return
        }
        
        // Get pixel buffer from sample buffer
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        // Process frame with Vision Manager
        visionManager?.processFrame(pixelBuffer) { [weak self] items, error in
            guard let self = self else { return }
            
            if let error = error {
                self.detectionError = "Detection error: \(error.localizedDescription)"
                return
            }
            
            if let items = items {
                // Update all detected objects
                self.detectedObjects = items
                
                // Match against current search query
                if let searchParameters = self.currentSearchParameters {
                    self.matchingObjects = self.objectMatcher.matchObjects(
                        detectedObjects: items,
                        searchParameters: searchParameters
                    )
                } else {
                    self.matchingObjects = []
                }
            }
        }
    }
} 