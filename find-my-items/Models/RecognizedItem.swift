//
//  RecognizedItem.swift
//  find-my-items
//
//  Created by Quang Tran Minh on 11/3/25.
//

import Foundation
import Vision
import CoreGraphics

/// Match type for recognized items to categorize different detection scenarios
enum MatchType {
    /// Exact match with the searched item
    case exactMatch
    /// Similar item to what the user is searching for
    case similarItem
    /// A potential location where the item might be hidden
    case potentialLocation
}

/// Model representing an item recognized by the vision system
struct RecognizedItem: Identifiable {
    /// Unique identifier for the item
    let id = UUID()
    /// The label or name of the recognized object
    let label: String
    /// Confidence score from 0.0 to 1.0
    let confidence: Float
    /// Bounding box of the object in normalized coordinates (0-1)
    let boundingBox: CGRect
    /// Type of match in relation to user's search query
    var matchType: MatchType = .similarItem
    /// Description of potential location (for potentialLocation type)
    var locationDescription: String?
    
    /// The center point of the bounding box in normalized coordinates
    var centerPoint: CGPoint {
        return CGPoint(
            x: boundingBox.midX,
            y: boundingBox.midY
        )
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
} 