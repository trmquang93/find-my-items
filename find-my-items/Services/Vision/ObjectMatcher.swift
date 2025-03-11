//
//  ObjectMatcher.swift
//  find-my-items
//
//  Created by AI Assistant on 11/3/25.
//

import Foundation
import NaturalLanguage
import Vision

/// Matcher for connecting detected objects with NLP-processed queries
class ObjectMatcher {
    // MARK: - Properties
    
    /// NLP processor for query understanding
    private let nlpProcessor = NLPProcessor()
    
    /// Word embeddings for semantic similarity
    private var wordEmbeddings: NLEmbedding?
    
    /// Dictionary of common synonyms for object names
    private let synonyms: [String: [String]] = [
        "laptop": ["computer", "notebook", "macbook"],
        "phone": ["smartphone", "mobile", "iphone", "android"],
        "cup": ["mug", "glass", "tumbler"],
        "sofa": ["couch", "loveseat", "settee"],
        "tv": ["television", "monitor", "screen"],
        "keys": ["key", "keychain", "keyring"],
        "wallet": ["billfold", "purse"],
        "glasses": ["spectacles", "eyeglasses", "sunglasses"],
        "headphones": ["earphones", "earbuds", "airpods"],
        "camera": ["webcam", "dslr", "digital camera"]
        // Add more synonyms as needed
    ]
    
    /// Containers and locations where objects might be
    private let containers: [String] = [
        "bag", "backpack", "purse", "box", "drawer", "cabinet", "shelf",
        "table", "desk", "chair", "sofa", "couch", "bed", "counter",
        "nightstand", "dresser", "credenza", "bookcase"
    ]
    
    // MARK: - Initialization
    
    init() {
        // Load word embeddings for semantic matching
        wordEmbeddings = NLEmbedding.wordEmbedding(for: .english)
    }
    
    // MARK: - Public Methods
    
    /// Match a natural language query against detected objects
    /// - Parameters:
    ///   - detectedObjects: Objects detected in the scene
    ///   - query: Natural language query from the user
    /// - Returns: Matched objects with match type and confidence
    func matchNaturalLanguageQuery(
        detectedObjects: [RecognizedItem],
        query: String
    ) -> [RecognizedItem] {
        // Process the query with NLP
        let searchParameters = nlpProcessor.processQuery(query)
        
        // Use the processed parameters for matching
        return matchObjects(
            detectedObjects: detectedObjects,
            searchParameters: searchParameters
        )
    }
    
    /// Match detected objects against search parameters
    /// - Parameters:
    ///   - detectedObjects: Objects detected in the scene
    ///   - searchParameters: Structured search parameters
    /// - Returns: Matched objects with match type and confidence
    func matchObjects(
        detectedObjects: [RecognizedItem],
        searchParameters: SearchParameters
    ) -> [RecognizedItem] {
        // If no search terms, return all objects
        guard searchParameters.hasSearchableContent else {
            return detectedObjects
        }
        
        // Create a new array to store matches with updated match types
        var matchedObjects: [RecognizedItem] = []
        
        // Process each detected object
        for object in detectedObjects {
            // Skip low-confidence detections
            if object.confidence < 0.4 {
                continue
            }
            
            // Calculate match score and type
            let (matchType, matchScore) = calculateMatch(
                detectedObject: object,
                searchParameters: searchParameters
            )
            
            // If it's a match, add to results with updated match type and score
            if let matchType = matchType {
                // Create a copy of the object with updated match properties
                let matchedObject = RecognizedItem(
                    label: object.label,
                    confidence: object.confidence,
                    boundingBox: object.boundingBox,
                    matchType: matchType,
                    locationDescription: object.locationDescription
                )
                
                // Update match score
                matchedObject.matchScore = matchScore
                
                // Copy world position if available
                if let worldPos = object.worldPosition {
                    matchedObject.updatePosition(worldPos, confidence: object.positionConfidence)
                }
                
                // For potential locations, add description
                if matchType == .potentialLocation {
                    matchedObject.locationDescription = generateLocationDescription(
                        container: object.label,
                        searchParameters: searchParameters
                    )
                }
                
                matchedObjects.append(matchedObject)
            }
        }
        
        // Sort by match type, match score, and confidence
        return matchedObjects.sorted { (obj1, obj2) -> Bool in
            // First prioritize by match type
            if obj1.matchType != obj2.matchType {
                if obj1.matchType == .exactMatch { return true }
                if obj2.matchType == .exactMatch { return false }
                if obj1.matchType == .similarItem { return true }
                if obj2.matchType == .similarItem { return false }
                if obj1.matchType == .potentialLocation { return true }
                return false
            }
            
            // Then by match score
            if obj1.matchScore != obj2.matchScore {
                return obj1.matchScore > obj2.matchScore
            }
            
            // Finally by detection confidence
            return obj1.confidence > obj2.confidence
        }
    }
    
    // MARK: - Private Methods
    
    /// Calculate match type and score for a detected object
    private func calculateMatch(
        detectedObject: RecognizedItem,
        searchParameters: SearchParameters
    ) -> (RecognizedItem.MatchType?, Float) {
        let objectLabel = detectedObject.label.lowercased()
        
        // 1. Check for direct object name matches (highest priority)
        for targetItem in searchParameters.targetItems {
            // Exact match
            if objectLabel == targetItem.lowercased() {
                let attributeScore = calculateAttributeMatch(
                    detectedObject: detectedObject,
                    attributes: searchParameters.attributes
                )
                
                // Combine exact match with attribute score
                let score = 0.8 + (0.2 * attributeScore)
                return (.exactMatch, score)
            }
        }
        
        // 2. Check for synonym matches
        for targetItem in searchParameters.targetItems {
            if isSynonym(word1: objectLabel, word2: targetItem) {
                let attributeScore = calculateAttributeMatch(
                    detectedObject: detectedObject,
                    attributes: searchParameters.attributes
                )
                
                // Combine synonym match with attribute score
                let score = 0.6 + (0.2 * attributeScore)
                return (.similarItem, score)
            }
        }
        
        // 3. Check for semantic similarity using word embeddings
        let semanticScore = calculateSemanticSimilarity(
            word: objectLabel,
            targetItems: searchParameters.targetItems
        )
        
        if semanticScore > 0.7 {
            let attributeScore = calculateAttributeMatch(
                detectedObject: detectedObject,
                attributes: searchParameters.attributes
            )
            
            // Combine semantic similarity with attribute score
            let score = (semanticScore * 0.6) + (attributeScore * 0.2)
            return (.similarItem, score)
        }
        
        // 4. Check for spatial relationship matches
        if let spatialMatch = checkSpatialRelationship(
            objectLabel: objectLabel,
            relationships: searchParameters.spatialRelationships
        ) {
            return (.potentialLocation, spatialMatch)
        }
        
        // 5. Check if this is a potential container
        if searchParameters.intent == .find && isContainer(objectLabel) && !searchParameters.targetItems.isEmpty {
            return (.potentialLocation, 0.5)
        }
        
        // No match
        return (nil, 0.0)
    }
    
    /// Calculate attribute match score between detected object and search attributes
    private func calculateAttributeMatch(
        detectedObject: RecognizedItem,
        attributes: SearchParameters.Attributes
    ) -> Float {
        // For full implementation, object detection would include attributes
        // This would match detected colors, sizes, etc. with query attributes
        
        // For now, return neutral score since detected objects don't have attributes yet
        return 0.5
    }
    
    /// Check if a detected object matches any spatial relationships
    private func checkSpatialRelationship(
        objectLabel: String,
        relationships: [SearchParameters.SpatialRelationship]
    ) -> Float? {
        for relationship in relationships {
            if objectLabel.lowercased() == relationship.referenceObject.lowercased() {
                return relationship.confidence
            }
            
            // Check synonyms of the reference object
            if isSynonym(word1: objectLabel, word2: relationship.referenceObject) {
                return relationship.confidence * 0.9  // Slightly lower confidence for synonyms
            }
        }
        
        return nil
    }
    
    /// Calculate semantic similarity between a word and target items
    private func calculateSemanticSimilarity(
        word: String,
        targetItems: [String]
    ) -> Float {
        guard let embeddings = wordEmbeddings else {
            return 0.0
        }
        
        var highestSimilarity: Float = 0.0
        
        for target in targetItems {
            if embeddings.contains(word) && embeddings.contains(target) {
                let similarity = embeddings.distance(between: word, and: target)
                // Convert distance to similarity (closer = more similar)
                let similarityScore = Float(1.0 - Double(similarity))
                highestSimilarity = max(highestSimilarity, similarityScore)
            }
        }
        
        return highestSimilarity
    }
    
    /// Check if two words are synonyms
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
    private func isContainer(_ label: String) -> Bool {
        return containers.contains(label.lowercased())
    }
    
    /// Generate a descriptive location text
    private func generateLocationDescription(
        container: String,
        searchParameters: SearchParameters
    ) -> String {
        // Check if there's a specific relationship in the search parameters
        for relationship in searchParameters.spatialRelationships {
            if isSynonym(word1: container, word2: relationship.referenceObject) {
                return "\(relationship.relationship.rawValue) the \(container)"
            }
        }
        
        // Fall back to generic description
        let prepositions = ["in", "on", "under", "near"]
        let preposition = prepositions.randomElement() ?? "near"
        
        return "\(preposition) the \(container)"
    }
} 
