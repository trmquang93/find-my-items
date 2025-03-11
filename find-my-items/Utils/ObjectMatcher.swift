//
//  ObjectMatcher.swift
//  find-my-items
//
//  Created by Quang Tran Minh on 11/3/25.
//

import Foundation

/// Class that matches detected objects with user search queries
class ObjectMatcher {
    // Dictionary of common synonyms for object names
    private let synonyms: [String: [String]] = [
        "laptop": ["computer", "notebook", "macbook"],
        "phone": ["smartphone", "mobile", "iphone", "android"],
        "cup": ["mug", "glass", "tumbler"],
        "sofa": ["couch", "loveseat", "settee"],
        "tv": ["television", "monitor", "screen"],
        "bottle": ["water bottle", "container", "flask"],
        "book": ["novel", "textbook", "magazine"],
        "remote": ["controller", "remote control"],
        "key": ["keys", "keychain", "keyring"],
        "wallet": ["purse", "billfold", "money clip"],
        "bag": ["backpack", "purse", "sack", "tote"],
        "headphones": ["earphones", "earbuds", "airpods"]
    ]
    
    // Containers and locations where objects might be
    private let containers: [String] = [
        "bag", "backpack", "purse", "box", "drawer", "cabinet", "shelf",
        "table", "desk", "chair", "sofa", "couch", "basket", "bin",
        "counter", "nightstand", "dresser", "closet", "bookshelf"
    ]
    
    /// Match a search query against a list of detected objects
    /// - Parameters:
    ///   - detectedObjects: List of detected objects from vision processing
    ///   - searchParameters: Parameters extracted from the user's search query
    /// - Returns: List of matched objects with updated match types
    func matchObjects(detectedObjects: [RecognizedItem], 
                     searchParameters: SearchParameters) -> [RecognizedItem] {
        // If no search terms, return all objects
        guard searchParameters.hasSearchableContent else {
            return detectedObjects
        }
        
        // Create a new array to store matches with updated match types
        var matchedObjects: [RecognizedItem] = []
        
        // Process each detected object
        for var object in detectedObjects {
            // Skip low-confidence detections
            if object.confidence < 0.4 {
                continue
            }
            
            // Calculate match type and score
            let (matchType, matchScore) = calculateMatchType(
                objectLabel: object.label.lowercased(),
                searchParameters: searchParameters
            )
            
            // If it's a match, add to results with updated match type
            if let matchType = matchType {
                object.matchType = matchType
                
                // For potential locations, add description
                if matchType == .potentialLocation {
                    object.locationDescription = generateLocationDescription(
                        container: object.label,
                        item: searchParameters.primaryTargetName
                    )
                }
                
                matchedObjects.append(object)
            }
        }
        
        // Sort by match type and confidence
        return matchedObjects.sorted { (obj1, obj2) -> Bool in
            // First, sort by match type (exact matches first)
            if obj1.matchType != obj2.matchType {
                if obj1.matchType == .exactMatch { return true }
                if obj2.matchType == .exactMatch { return false }
                if obj1.matchType == .similarItem { return true }
                return false
            }
            
            // Then sort by confidence
            return obj1.confidence > obj2.confidence
        }
    }
    
    /// Calculate match type for an object based on search parameters
    /// - Parameters:
    ///   - objectLabel: The label of the detected object
    ///   - searchParameters: Parameters from the user's search query
    /// - Returns: Match type and confidence score tuple
    private func calculateMatchType(
        objectLabel: String,
        searchParameters: SearchParameters
    ) -> (MatchType?, Float) {
        // Check for exact matches
        for targetItem in searchParameters.targetItems {
            if objectLabel == targetItem.lowercased() {
                return (.exactMatch, 1.0)
            }
        }
        
        // Check for synonym matches
        for targetItem in searchParameters.targetItems {
            if isSynonym(word1: objectLabel, word2: targetItem) {
                return (.similarItem, 0.8)
            }
        }
        
        // Check for attribute matches (e.g., color)
        // This would be more complex in a full implementation
        
        // Check if this is a potential container/location
        if isContainer(objectLabel) && !searchParameters.targetItems.isEmpty {
            return (.potentialLocation, 0.6)
        }
        
        return (nil, 0.0)
    }
    
    /// Check if two words are synonyms
    /// - Parameters:
    ///   - word1: First word to compare
    ///   - word2: Second word to compare
    /// - Returns: True if the words are synonyms
    private func isSynonym(word1: String, word2: String) -> Bool {
        let word1Lower = word1.lowercased()
        let word2Lower = word2.lowercased()
        
        // Direct match
        if word1Lower == word2Lower {
            return true
        }
        
        // Check in synonyms dictionary
        if let synonymsOfWord1 = synonyms[word1Lower], synonymsOfWord1.contains(word2Lower) {
            return true
        }
        
        if let synonymsOfWord2 = synonyms[word2Lower], synonymsOfWord2.contains(word1Lower) {
            return true
        }
        
        return false
    }
    
    /// Check if the label represents a container or location
    /// - Parameter label: The object label to check
    /// - Returns: True if the label is a known container
    private func isContainer(_ label: String) -> Bool {
        return containers.contains(label.lowercased())
    }
    
    /// Generate a description for potential locations
    /// - Parameters:
    ///   - container: The container/location object
    ///   - item: The item being searched for
    /// - Returns: A human-readable description of where the item might be
    private func generateLocationDescription(container: String, item: String) -> String {
        let prepositions = ["in", "on", "under", "near"]
        let preposition = prepositions.randomElement() ?? "in"
        
        return "\(preposition) the \(container)"
    }
} 