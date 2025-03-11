//
//  NLPProcessor.swift
//  find-my-items
//
//  Created by AI Assistant on 11/3/25.
//

import Foundation
import NaturalLanguage

/// A service that processes natural language queries to extract search parameters
class NLPProcessor {
    // MARK: - Types
    
    /// Types of intents supported by the processor
    enum QueryIntent {
        case findObject           // "Find my keys"
        case locateNearby         // "Is my wallet near the couch?"
        case describeScene        // "What's in this room?"
        case navigateToObject     // "Take me to my laptop"
        case remember             // "Remember where I put my watch"
        case unknown              // Could not determine intent
    }
    
    /// Attributes extracted from a query
    struct QueryAttributes {
        var colors: [String] = []
        var sizes: [String] = []
        var materials: [String] = []
        var ownership: Ownership = .unknown
        var timeReferences: [String] = []
        var locationReferences: [String] = []
    }
    
    /// Ownership modifier for objects
    enum Ownership {
        case mine
        case others
        case unknown
    }
    
    // MARK: - Properties
    
    /// NL Tagger for part-of-speech analysis
    private let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType, .lemma])
    
    /// NL Model for custom entity recognition (if available)
    private var entityRecognizer: NLModel?
    
    /// Word embeddings for similarity search
    private var wordEmbeddings: NLEmbedding?
    
    // MARK: - Initialization
    
    init() {
        // Load pre-trained embeddings for word similarity
        wordEmbeddings = NLEmbedding.wordEmbedding(for: .english)
        
        // Attempt to load custom entity recognition model if available
        do {
            if let modelURL = Bundle.main.url(forResource: "ItemEntityRecognizer", withExtension: "mlmodelc") {
                entityRecognizer = try NLModel(contentsOf: modelURL)
            }
        } catch {
            print("Failed to load custom entity model: \(error)")
        }
    }
    
    // MARK: - Public Methods
    
    /// Process a natural language query and extract search parameters
    /// - Parameter query: The user's natural language query
    /// - Returns: Structured search parameters
    func processQuery(_ query: String) -> SearchParameters {
        // Prepare the text for processing
        let processedText = preprocess(query)
        
        // Determine the intent of the query
        let intent = determineIntent(query: processedText)
        
        // Extract target items (objects the user is looking for)
        let targetItems = extractTargetItems(from: processedText)
        
        // Extract attributes (color, size, etc.)
        let attributes = extractAttributes(from: processedText)
        
        // Extract spatial relationships
        let spatialRelationships = extractSpatialRelationships(from: processedText)
        
        // Convert processor-specific types to SearchParameters types
        return createSearchParameters(
            intent: intent,
            targetItems: targetItems,
            attributes: attributes,
            spatialRelationships: spatialRelationships,
            rawQuery: query
        )
    }
    
    // MARK: - Private Processing Methods
    
    /// Preprocess the text for analysis
    private func preprocess(_ text: String) -> String {
        // Lowercase for consistency
        let lowercased = text.lowercased()
        
        // Additional preprocessing as needed
        
        return lowercased
    }
    
    /// Determine the intent of the query
    private func determineIntent(query: String) -> QueryIntent {
        // Look for intent-specific patterns
        if query.contains("find ") || query.contains("where") || query.contains("locate") {
            return .findObject
        } else if query.contains("near") || query.contains("close to") || query.contains("by the") {
            return .locateNearby
        } else if query.contains("what") && (query.contains("room") || query.contains("here")) {
            return .describeScene
        } else if query.contains("take me") || query.contains("navigate") || query.contains("go to") {
            return .navigateToObject
        } else if query.contains("remember") || query.contains("note") {
            return .remember
        }
        
        // Default intent
        return .findObject
    }
    
    /// Extract target items (objects the user is looking for)
    private func extractTargetItems(from query: String) -> [String] {
        var targetItems: [String] = []
        
        // Configure tagger
        tagger.string = query
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace]
        
        // Tag for parts of speech
        tagger.enumerateTags(in: query.startIndex..<query.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, tokenRange in
            if let tag = tag, tag == .noun {
                let token = String(query[tokenRange])
                
                // Filter out common non-object words
                if isLikelyObject(token) {
                    targetItems.append(token)
                }
            }
            return true
        }
        
        // If we found specific objects, return them
        if !targetItems.isEmpty {
            return targetItems
        }
        
        // Fallback to more basic extraction if POS tagging didn't yield results
        // This handles cases where the NL tagger might not be effective
        let commonPrefixes = ["my ", "the ", "a ", "find ", "where is ", "locate "]
        var processedQuery = query
        
        for prefix in commonPrefixes {
            if processedQuery.hasPrefix(prefix) {
                processedQuery = String(processedQuery.dropFirst(prefix.count))
            }
        }
        
        // Split by common connectors and take the first part
        let connectors = [" in ", " on ", " near ", " by ", " under ", " around ", " at "]
        for connector in connectors {
            if let range = processedQuery.range(of: connector) {
                processedQuery = String(processedQuery[..<range.lowerBound])
            }
        }
        
        // If we still have content, add it as a target
        if !processedQuery.isEmpty {
            targetItems.append(processedQuery.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        return targetItems
    }
    
    /// Extract attributes like color, size, material
    private func extractAttributes(from query: String) -> QueryAttributes {
        var attributes = QueryAttributes()
        
        // Check for colors
        let colors = ["red", "blue", "green", "yellow", "black", "white", "brown", 
                     "purple", "pink", "orange", "gray", "silver", "gold"]
        
        for color in colors {
            if query.contains(color) {
                attributes.colors.append(color)
            }
        }
        
        // Check for size indicators
        let sizes = ["small", "large", "big", "tiny", "huge", "medium"]
        for size in sizes {
            if query.contains(size) {
                attributes.sizes.append(size)
            }
        }
        
        // Check for materials
        let materials = ["leather", "metal", "plastic", "wooden", "glass", "ceramic", "cloth"]
        for material in materials {
            if query.contains(material) {
                attributes.materials.append(material)
            }
        }
        
        // Check for ownership
        if query.contains("my ") || query.contains(" mine") {
            attributes.ownership = .mine
        } else if query.contains("their ") || query.contains("his ") || query.contains("her ") {
            attributes.ownership = .others
        }
        
        // Check for location references
        let locations = ["table", "desk", "chair", "couch", "bed", "floor", "shelf", 
                        "drawer", "kitchen", "bathroom", "bedroom", "living room"]
        for location in locations {
            if query.contains(location) {
                attributes.locationReferences.append(location)
            }
        }
        
        // Check for time references
        let timeReferences = ["morning", "afternoon", "evening", "night", 
                             "yesterday", "today", "earlier", "before"]
        for timeRef in timeReferences {
            if query.contains(timeRef) {
                attributes.timeReferences.append(timeRef)
            }
        }
        
        return attributes
    }
    
    /// Extract spatial relationships between objects
    private func extractSpatialRelationships(from query: String) -> [SearchParameters.SpatialRelationship] {
        var relationships: [SearchParameters.SpatialRelationship] = []
        
        // Define prepositions that indicate spatial relationships
        let spatialPrepositions = [
            "near": SearchParameters.SpatialRelationship.Relationship.near,
            "on": .on,
            "under": .under,
            "inside": .inside,
            "behind": .behind,
            "in front of": .inFrontOf,
            "next to": .nextTo,
            "between": .between,
            "above": .above,
            "below": .below
        ]
        
        // Look for patterns like "X near Y", "X on Y", etc.
        for (preposition, relationship) in spatialPrepositions {
            if let range = query.range(of: preposition) {
                // Get the text after the preposition
                let afterPreposition = String(query[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Extract the reference object (basic implementation - could be improved)
                if let firstSpace = afterPreposition.firstIndex(of: " ") {
                    let referenceObject = String(afterPreposition[..<firstSpace])
                    if isLikelyObject(referenceObject) {
                        let spatialRelationship = SearchParameters.SpatialRelationship(
                            referenceObject: referenceObject,
                            relationship: relationship,
                            confidence: 0.8  // Fixed confidence - could be improved
                        )
                        relationships.append(spatialRelationship)
                    }
                } else if !afterPreposition.isEmpty {
                    // If there's no space, use the entire string after the preposition
                    let spatialRelationship = SearchParameters.SpatialRelationship(
                        referenceObject: afterPreposition,
                        relationship: relationship,
                        confidence: 0.8  // Fixed confidence - could be improved
                    )
                    relationships.append(spatialRelationship)
                }
            }
        }
        
        return relationships
    }
    
    /// Determine if a word is likely to be an object (not a function word)
    private func isLikelyObject(_ word: String) -> Bool {
        // Common words that are unlikely to be objects
        let nonObjectWords = ["the", "a", "an", "this", "that", "these", "those", 
                             "i", "you", "he", "she", "it", "we", "they",
                             "in", "on", "at", "by", "with", "from", "to"]
        
        // Check if it's in our exclusion list
        if nonObjectWords.contains(word) {
            return false
        }
        
        // Additional checks could include:
        // 1. Word length (very short words are often not objects)
        // 2. Part of speech verification
        // 3. Checking against a known list of common objects
        
        return true
    }
    
    /// Create a SearchParameters object from the extracted data
    private func createSearchParameters(
        intent: QueryIntent,
        targetItems: [String],
        attributes: QueryAttributes,
        spatialRelationships: [SearchParameters.SpatialRelationship],
        rawQuery: String
    ) -> SearchParameters {
        // Convert processor intent to SearchParameters intent
        let searchIntent: SearchParameters.Intent
        switch intent {
        case .findObject:
            searchIntent = .find
        case .locateNearby:
            searchIntent = .locateNearby
        case .describeScene:
            searchIntent = .describe
        case .navigateToObject:
            searchIntent = .navigate
        case .remember:
            searchIntent = .remember
        case .unknown:
            searchIntent = .unknown
        }
        
        // Convert processor attributes to SearchParameters attributes
        var searchAttributes = SearchParameters.Attributes(
            colors: attributes.colors,
            sizes: attributes.sizes,
            materials: attributes.materials
        )
        
        // Set ownership
        searchAttributes.isMine = attributes.ownership == .mine
        
        // Add time references and locations
        searchAttributes.timeReferences = attributes.timeReferences
        searchAttributes.locations = attributes.locationReferences
        
        // Calculate overall confidence
        // This is a simple implementation - in a real app, we would calculate
        // confidence based on multiple factors
        let confidence: Float = 0.8
        
        return SearchParameters(
            targetItems: targetItems,
            intent: searchIntent,
            attributes: searchAttributes,
            spatialRelationships: spatialRelationships,
            rawQuery: rawQuery,
            confidence: confidence
        )
    }
    
    /// Find similar words using word embeddings
    private func findSimilarWords(to word: String, count: Int = 5) -> [String] {
        guard let embeddings = wordEmbeddings,
              embeddings.contains(word) else {
            return []
        }
        
        return embeddings.neighbors(for: word, maximumCount: count)
            .map { $0.0 }
    }
} 