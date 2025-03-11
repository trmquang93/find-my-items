//
//  CameraPreview.swift
//  find-my-items
//
//  Created by Quang Tran Minh on 11/3/25.
//

import SwiftUI
import AVFoundation
import UIKit

/// A SwiftUI view that represents the camera preview
struct CameraPreview: UIViewRepresentable {
    /// Camera manager to get the preview layer from
    let cameraManager: CameraManager
    
    /// Creates a UIView from a SwiftUI view
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        let previewLayer = cameraManager.getPreviewLayer()
        previewLayer.frame = view.bounds
        
        view.layer.addSublayer(previewLayer)
        
        // Add tap gesture to handle focus
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tapGesture)
        
        return view
    }
    
    /// Updates the view when SwiftUI state changes
    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.bounds
        }
    }
    
    /// Creates a coordinator to handle interactions
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    /// Coordinator class to handle UI interactions
    class Coordinator: NSObject {
        var parent: CameraPreview
        
        init(_ parent: CameraPreview) {
            self.parent = parent
        }
        
        /// Handle tap gestures for camera focus
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let view = gesture.view!
            let location = gesture.location(in: view)
            
            // Convert tap coordinates to normalized values (0-1)
            let normalizedPoint = CGPoint(
                x: location.x / view.bounds.width,
                y: location.y / view.bounds.height
            )
            
            // Focus camera at the tapped point
            parent.cameraManager.focusCamera(at: normalizedPoint)
            
            // Show visual feedback for focus point
            let focusView = UIView(frame: CGRect(x: 0, y: 0, width: 70, height: 70))
            focusView.center = location
            focusView.backgroundColor = UIColor.white.withAlphaComponent(0.3)
            focusView.layer.cornerRadius = 35
            focusView.layer.borderWidth = 2
            focusView.layer.borderColor = UIColor.white.cgColor
            view.addSubview(focusView)
            
            // Animate focus view
            UIView.animate(withDuration: 0.3, animations: {
                focusView.alpha = 0.6
                focusView.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
            }, completion: { _ in
                UIView.animate(withDuration: 0.2, animations: {
                    focusView.alpha = 0
                }, completion: { _ in
                    focusView.removeFromSuperview()
                })
            })
        }
    }
} 