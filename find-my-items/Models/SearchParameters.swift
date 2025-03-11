//
//  SearchParameters.swift
//  find-my-items
//
//  Created by Quang Tran Minh on 11/3/25.
//

import Foundation

/// Model representing search parameters derived from a user's search query
struct SearchParameters {
    /// Main items the user is looking for
    let targetItems: [String]
    
    /// Possible locations where the item might be (e.g., "under", "inside", "on top of")
    let possibleLocations: [String]
    
    /// Additional objects that might be related to the search (e.g., "couch" in "look for keys under the couch")
    let relatedObjects: [String]
    
    /// Additional attributes of the target item (e.g., color, size, shape)
    let attributes: [String: String]
    
    /// Creates a new search parameters object
    /// - Parameters:
    ///   - targetItems: Array of target item names
    ///   - possibleLocations: Array of possible locations (prepositions)
    ///   - relatedObjects: Array of related object names
    ///   - attributes: Dictionary of attribute name to value
    init(
        targetItems: [String] = [],
        possibleLocations: [String] = [],
        relatedObjects: [String] = [],
        attributes: [String: String] = [:]
    ) {
        self.targetItems = targetItems
        self.possibleLocations = possibleLocations
        self.relatedObjects = relatedObjects
        self.attributes = attributes
    }
    
    /// Returns true if the search parameters contain any usable information
    var hasSearchableContent: Bool {
        return !targetItems.isEmpty || !attributes.isEmpty
    }
    
    /// Returns the primary target item name, or an empty string if none
    var primaryTargetName: String {
        return targetItems.first ?? ""
    }
} 