//
//  CameraManager.swift
//  find-my-items
//
//  Created by Quang Tran Minh on 11/3/25.
//

import AVFoundation
import Combine
import SwiftUI

/// Camera permission status
enum CameraPermissionStatus {
    /// Camera access is authorized
    case authorized
    /// Camera access is denied
    case denied
    /// Camera access is not yet determined
    case notDetermined
    /// Camera access is restricted
    case restricted
}

/// Class responsible for managing camera operations
class CameraManager: NSObject, ObservableObject {
    /// The capture session for the camera
    @Published var session = AVCaptureSession()
    
    /// The current permission status for camera access
    @Published var permissionStatus: CameraPermissionStatus = .notDetermined
    
    /// Whether the camera is currently running
    @Published var isRunning = false
    
    /// The preview layer for displaying camera output in a view
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    /// Queue for handling camera session operations
    private let sessionQueue = DispatchQueue(label: "com.findmyitems.sessionQueue")
    
    /// Video data output for the camera
    private var videoDataOutput = AVCaptureVideoDataOutput()
    
    /// Output delegate for processing video frames
    weak var videoOutputDelegate: AVCaptureVideoDataOutputSampleBufferDelegate?
    
    /// Initialize the camera manager
    override init() {
        super.init()
        checkPermissions()
    }
    
    /// Check camera permissions and update status
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.permissionStatus = .authorized
            self.setupCaptureSession()
        case .notDetermined:
            self.permissionStatus = .notDetermined
            self.requestPermissions()
        case .denied:
            self.permissionStatus = .denied
        case .restricted:
            self.permissionStatus = .restricted
        @unknown default:
            self.permissionStatus = .notDetermined
        }
    }
    
    /// Request camera permissions
    func requestPermissions() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.permissionStatus = .authorized
                    self?.setupCaptureSession()
                } else {
                    self?.permissionStatus = .denied
                }
            }
        }
    }
    
    /// Setup the capture session
    private func setupCaptureSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            
            // Add video input
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice),
                  self.session.canAddInput(videoDeviceInput) else {
                self.session.commitConfiguration()
                return
            }
            
            self.session.addInput(videoDeviceInput)
            
            // Add video output
            if self.session.canAddOutput(self.videoDataOutput) {
                self.session.addOutput(self.videoDataOutput)
                self.videoDataOutput.setSampleBufferDelegate(self.videoOutputDelegate, queue: self.sessionQueue)
                self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
                
                if let connection = self.videoDataOutput.connection(with: .video) {
                    connection.isVideoMirrored = false
                    connection.videoOrientation = .portrait
                }
            }
            
            self.session.commitConfiguration()
            self.startSession()
        }
    }
    
    /// Start the camera session
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.session.isRunning else { return }
            self.session.startRunning()
            DispatchQueue.main.async {
                self.isRunning = self.session.isRunning
            }
        }
    }
    
    /// Stop the camera session
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async {
                self.isRunning = self.session.isRunning
            }
        }
    }
    
    /// Get a preview layer for the camera feed
    /// - Returns: An AVCaptureVideoPreviewLayer configured for the session
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer {
        if let existingLayer = previewLayer {
            return existingLayer
        }
        
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        previewLayer = layer
        return layer
    }
    
    /// Set the video output delegate for processing frames
    func setVideoOutputDelegate(_ delegate: AVCaptureVideoDataOutputSampleBufferDelegate) {
        videoOutputDelegate = delegate
        
        // If already set up, update the delegate
        if session.outputs.contains(videoDataOutput) {
            sessionQueue.async { [weak self] in
                self?.videoDataOutput.setSampleBufferDelegate(delegate, queue: self?.sessionQueue)
            }
        }
    }
    
    /// Toggle camera torch (flashlight) on/off
    /// - Parameter isOn: Whether the torch should be turned on
    func toggleTorch(isOn: Bool) {
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        
        if device.hasTorch && device.isTorchAvailable {
            do {
                try device.lockForConfiguration()
                device.torchMode = isOn ? .on : .off
                device.unlockForConfiguration()
            } catch {
                print("Error toggling torch: \(error)")
            }
        }
    }
    
    /// Focus camera at a specific point
    /// - Parameter point: Normalized point (0-1) where to focus
    func focusCamera(at point: CGPoint) {
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        
        do {
            try device.lockForConfiguration()
            
            if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
            }
            
            if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose) {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Error focusing camera: \(error)")
        }
    }
} 