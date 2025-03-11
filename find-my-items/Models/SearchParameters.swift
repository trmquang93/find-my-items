//
//  SearchParameters.swift
//  find-my-items
//
//  Created by Quang Tran Minh on 11/3/25.
//

import Foundation

/// Model representing parameters extracted from a natural language search query
struct SearchParameters {
    // MARK: - Types
    
    /// Represents the intent of a user's query
    enum Intent {
        case find            // Basic find intent (where is X)
        case locateNearby    // Find X near Y
        case describe        // What objects are in the scene
        case navigate        // Guide me to X
        case remember        // Remember where X is
        case unknown         // Could not determine intent
    }
    
    /// Represents a spatial relationship between objects
    struct SpatialRelationship {
        /// The reference object (e.g., "couch" in "keys near the couch")
        let referenceObject: String
        
        /// The type of relationship
        let relationship: Relationship
        
        /// The confidence in this relationship (0.0-1.0)
        let confidence: Float
        
        /// Types of spatial relationships
        enum Relationship: String {
            case near = "near"
            case on = "on"
            case under = "under"
            case inside = "inside"
            case behind = "behind"
            case inFrontOf = "in front of"
            case nextTo = "next to"
            case between = "between"
            case above = "above"
            case below = "below"
        }
    }
    
    /// Represents object attributes extracted from a query
    struct Attributes {
        /// Color attributes (e.g., "blue", "red")
        var colors: [String] = []
        
        /// Size attributes (e.g., "large", "small")
        var sizes: [String] = []
        
        /// Material attributes (e.g., "leather", "metal")
        var materials: [String] = []
        
        /// Temporal references (e.g., "this morning", "yesterday")
        var timeReferences: [String] = []
        
        /// Location references (e.g., "kitchen", "bedroom")
        var locations: [String] = []
        
        /// Whether the object belongs to the user
        var isMine: Bool = false
        
        /// Returns true if this set of attributes has any values
        var hasAttributes: Bool {
            return !colors.isEmpty || !sizes.isEmpty || !materials.isEmpty ||
                   !timeReferences.isEmpty || !locations.isEmpty || isMine
        }
        
        /// Creates a dictionary of attributes for compatibility with older code
        var asDictionary: [String: String] {
            var result: [String: String] = [:]
            
            if !colors.isEmpty {
                result["color"] = colors.joined(separator: ",")
            }
            
            if !sizes.isEmpty {
                result["size"] = sizes.joined(separator: ",")
            }
            
            if !materials.isEmpty {
                result["material"] = materials.joined(separator: ",")
            }
            
            if isMine {
                result["ownership"] = "mine"
            }
            
            return result
        }
    }
    
    // MARK: - Properties
    
    /// Primary target items the user is looking for (e.g., ["keys", "wallet"])
    let targetItems: [String]
    
    /// The interpreted intent of the query
    let intent: Intent
    
    /// Attributes describing the target items
    let attributes: Attributes
    
    /// Spatial relationships between the target and other objects
    let spatialRelationships: [SpatialRelationship]
    
    /// Raw query text that generated these parameters
    let rawQuery: String?
    
    /// Overall confidence in the parameter extraction (0.0-1.0)
    let confidence: Float
    
    /// Returns true if the parameters contain searchable content
    var hasSearchableContent: Bool {
        return !targetItems.isEmpty || attributes.hasAttributes || !spatialRelationships.isEmpty
    }
    
    /// The primary target name, or first target item
    var primaryTargetName: String {
        return targetItems.first ?? ""
    }
    
    /// For compatibility with old code - extract possible locations from spatial relationships
    var possibleLocations: [String] {
        return spatialRelationships.map { $0.relationship.rawValue }
    }
    
    /// For compatibility with old code - extract related objects from spatial relationships
    var relatedObjects: [String] {
        return spatialRelationships.map { $0.referenceObject }
    }
    
    // MARK: - Initialization
    
    /// Create search parameters with full NLP extraction
    init(
        targetItems: [String],
        intent: Intent = .find,
        attributes: Attributes = Attributes(),
        spatialRelationships: [SpatialRelationship] = [],
        rawQuery: String? = nil,
        confidence: Float = 1.0
    ) {
        self.targetItems = targetItems
        self.intent = intent
        self.attributes = attributes
        self.spatialRelationships = spatialRelationships
        self.rawQuery = rawQuery
        self.confidence = confidence
    }
    
    /// Create search parameters from a simple query string (legacy support)
    init(simpleQuery: String) {
        // Split by spaces and filter empty strings
        let items = simpleQuery.lowercased()
            .components(separatedBy: CharacterSet(charactersIn: " ,;"))
            .filter { !$0.isEmpty }
        
        self.targetItems = items
        self.intent = .find
        self.attributes = Attributes()
        self.spatialRelationships = []
        self.rawQuery = simpleQuery
        self.confidence = 1.0
    }
    
    /// Legacy initialization method for backward compatibility
    init(
        targetItems: [String] = [],
        possibleLocations: [String] = [],
        relatedObjects: [String] = [],
        attributes: [String: String] = [:]
    ) {
        self.targetItems = targetItems
        self.intent = .find
        
        // Convert string dictionary to structured attributes
        var structuredAttributes = Attributes()
        
        // Extract color if present
        if let colorString = attributes["color"] {
            structuredAttributes.colors = colorString.components(separatedBy: ",")
        }
        
        // Extract size if present
        if let sizeString = attributes["size"] {
            structuredAttributes.sizes = sizeString.components(separatedBy: ",")
        }
        
        // Extract material if present
        if let materialString = attributes["material"] {
            structuredAttributes.materials = materialString.components(separatedBy: ",")
        }
        
        // Extract ownership if present
        if attributes["ownership"] == "mine" {
            structuredAttributes.isMine = true
        }
        
        self.attributes = structuredAttributes
        
        // Create spatial relationships from locations and related objects
        var relationships: [SpatialRelationship] = []
        
        if possibleLocations.count > 0 && relatedObjects.count > 0 {
            let minCount = min(possibleLocations.count, relatedObjects.count)
            
            for i in 0..<minCount {
                if let relationship = SpatialRelationship.Relationship(rawValue: possibleLocations[i]) {
                    relationships.append(SpatialRelationship(
                        referenceObject: relatedObjects[i],
                        relationship: relationship,
                        confidence: 1.0
                    ))
                }
            }
        }
        
        self.spatialRelationships = relationships
        self.rawQuery = nil
        self.confidence = 1.0
    }
    
    // MARK: - Methods
    
    /// Returns a description of what's being searched for
    func describeSearch() -> String {
        var description = ""
        
        // Add intent description
        switch intent {
        case .find:
            description += "Looking for "
        case .locateNearby:
            description += "Finding "
        case .describe:
            description += "Describing "
        case .navigate:
            description += "Navigating to "
        case .remember:
            description += "Remembering "
        case .unknown:
            description += "Searching for "
        }
        
        // Add attributes
        var attributesString = ""
        if !attributes.colors.isEmpty {
            attributesString += attributes.colors.joined(separator: "/") + " "
        }
        
        if !attributes.sizes.isEmpty {
            attributesString += attributes.sizes.joined(separator: "/") + " "
        }
        
        if !attributes.materials.isEmpty {
            attributesString += attributes.materials.joined(separator: "/") + " "
        }
        
        // Add target items
        if !targetItems.isEmpty {
            description += attributesString + targetItems.joined(separator: ", ")
        } else {
            description += "items"
        }
        
        // Add spatial relationships
        if !spatialRelationships.isEmpty {
            let relationship = spatialRelationships[0]
            description += " \(relationship.relationship.rawValue) \(relationship.referenceObject)"
        }
        
        return description
    }
} 