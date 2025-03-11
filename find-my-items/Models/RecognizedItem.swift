//
//  RecognizedItem.swift
//  find-my-items
//
//  Created by Quang Tran Minh on 11/3/25.
//

import Foundation
import Vision
import CoreGraphics
import SwiftUI
import simd
import Combine

/// Represents an object recognized by Vision and visualized in AR
class RecognizedItem: Identifiable, ObservableObject {
    // MARK: - Types
    
    /// The type of match between a query and a detected object
    enum MatchType {
        case exactMatch        // Direct match with search term
        case similarItem       // Similar to search term (synonym or semantically similar)
        case potentialLocation // Potential location where the item might be
        case partialMatch      // Only some attributes match
    }
    
    /// The current interaction state with this item
    enum InteractionState {
        case normal       // Default state
        case highlighted  // Briefly highlighted (e.g., when found)
        case selected     // User has selected this item
        case focused      // Camera is focused on this item
        case targeted     // Target of current search
    }
    
    // MARK: - Properties
    
    /// Unique identifier for the item
    let id = UUID()
    
    /// The label/name of the detected object
    let label: String
    
    /// The confidence level from object detection (0.0-1.0)
    let confidence: Float
    
    /// The bounding box in normalized coordinates (0.0-1.0)
    let boundingBox: CGRect
    
    /// The type of match with the current search query
    @Published var matchType: MatchType?
    
    /// The match score for the current search query (0.0-1.0)
    @Published var matchScore: Float = 0.0
    
    /// Description of the object's location relative to other objects
    @Published var locationDescription: String?
    
    /// The current interaction state
    @Published var interactionState: InteractionState = .normal
    
    /// 3D position in AR world space (if available)
    @Published var worldPosition: simd_float3?
    
    /// Estimated real-world size in meters (if available)
    @Published var estimatedSize: simd_float3?
    
    /// Distance from camera in meters (if available)
    @Published var distanceFromCamera: Float?
    
    /// Whether this item is anchored in AR (has stable tracking)
    @Published var isAnchored: Bool = false
    
    /// Confidence in AR position (0.0-1.0)
    @Published var positionConfidence: Float = 0.0
    
    /// History of positions for stability tracking
    private var positionHistory: [simd_float3] = []
    
    /// Number of frames this object has been continuously detected
    @Published var continuousDetectionCount: Int = 1
    
    /// Last time this object was detected
    @Published var lastDetectionTime: Date = Date()
    
    /// The center point of the bounding box in normalized coordinates
    var centerPoint: CGPoint {
        return CGPoint(
            x: boundingBox.midX,
            y: boundingBox.midY
        )
    }
    
    /// Color for visualization, based on match type
    var color: Color {
        switch matchType {
        case .exactMatch:
            return .green
        case .similarItem:
            return .blue
        case .potentialLocation:
            return .orange
        case .partialMatch:
            return .yellow
        case nil:
            return .gray
        }
    }
    
    /// Opacity for visualization, based on confidence and match score
    var visualOpacity: Double {
        return Double(max(confidence, matchScore) * 0.7 + 0.3)
    }
    
    /// Animation scale factor based on interaction state
    var animationScale: CGFloat {
        switch interactionState {
        case .normal:
            return 1.0
        case .highlighted:
            return 1.2
        case .selected:
            return 1.15
        case .focused:
            return 1.1
        case .targeted:
            return 1.3
        }
    }
    
    // MARK: - Initialization
    
    /// Initialize with basic recognition data
    init(
        label: String,
        confidence: Float,
        boundingBox: CGRect,
        matchType: MatchType? = nil,
        locationDescription: String? = nil
    ) {
        self.label = label
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.matchType = matchType
        self.locationDescription = locationDescription
    }
    
    /// Creates a recognized item from a VNRecognizedObjectObservation
    static func from(observation: VNRecognizedObjectObservation) -> RecognizedItem? {
        guard let topLabelObservation = observation.labels.first else {
            return nil
        }
        
        return RecognizedItem(
            label: topLabelObservation.identifier,
            confidence: topLabelObservation.confidence,
            boundingBox: observation.boundingBox
        )
    }
    
    // MARK: - Methods
    
    /// Update the 3D position of this item
    /// - Parameters:
    ///   - position: The new world position
    ///   - confidence: Confidence in the position (0.0-1.0)
    func updatePosition(_ position: simd_float3, confidence: Float) {
        // Store the new position
        worldPosition = position
        
        // Add to position history (limit to last 10 positions)
        positionHistory.append(position)
        if positionHistory.count > 10 {
            positionHistory.removeFirst()
        }
        
        // Update position confidence
        positionConfidence = confidence
        
        // If we have enough history, check stability and anchor if stable
        if positionHistory.count >= 5 {
            checkPositionStability()
        }
    }
    
    /// Update the detection count and time
    func updateDetection() {
        continuousDetectionCount += 1
        lastDetectionTime = Date()
    }
    
    /// Check if detection is still recent
    /// - Parameter timeThreshold: Time threshold in seconds
    /// - Returns: True if detection is recent
    func isRecentDetection(timeThreshold: TimeInterval = 2.0) -> Bool {
        return Date().timeIntervalSince(lastDetectionTime) <= timeThreshold
    }
    
    /// Generate a description for AR display
    func generateARDescription() -> String {
        var description = label
        
        if let matchType = matchType, matchScore > 0.7 {
            switch matchType {
            case .exactMatch:
                description += " (Exact Match)"
            case .similarItem:
                description += " (Similar Item)"
            case .potentialLocation:
                if let locationDescription = locationDescription {
                    description = "Look \(locationDescription) for your item"
                }
            case .partialMatch:
                description += " (Partial Match)"
            }
        }
        
        if let distance = distanceFromCamera, distance > 0 {
            let distanceString = String(format: "%.1f", distance)
            description += " (\(distanceString)m away)"
        }
        
        return description
    }
    
    // MARK: - Private Methods
    
    /// Check if the position is stable enough to be anchored
    private func checkPositionStability() {
        // Calculate the average distance between positions
        var totalDistance: Float = 0
        var comparisonCount = 0
        
        for i in 0..<positionHistory.count {
            for j in i+1..<positionHistory.count {
                totalDistance += distance(positionHistory[i], positionHistory[j])
                comparisonCount += 1
            }
        }
        
        // Calculate average movement
        let averageMovement = comparisonCount > 0 ? totalDistance / Float(comparisonCount) : 0
        
        // If average movement is below threshold, consider position stable
        if averageMovement < 0.05 { // 5cm threshold
            isAnchored = true
        }
    }
    
    /// Calculate distance between two 3D points
    private func distance(_ a: simd_float3, _ b: simd_float3) -> Float {
        return length(a - b)
    }
} 