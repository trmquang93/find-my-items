//
//  ModelLoader.swift
//  find-my-items
//
//  Created by Quang Tran Minh on 11/3/25.
//

import Foundation
import CoreML

/// Helper for loading and managing ML models
class ModelLoader {
    /// Checks if a model exists in the bundle
    static func modelExists(_ modelName: String) -> Bool {
        return Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") != nil
    }
    
    /// Gets the URL for a model in the bundle
    static func getModelURL(_ modelName: String) -> URL? {
        return Bundle.main.url(forResource: modelName, withExtension: "mlmodelc")
    }
    
    /// Returns information about available models
    static func getAvailableModels() -> [String: String] {
        let models = [
            "MobileNetV2": "General object detection model capable of identifying 1000 common objects",
            // Add more models as they become available
        ]
        
        // Filter to only models that actually exist in the bundle
        return models.filter { modelExists($0.key) }
    }
    
    /// Returns a human-readable description of what the model can detect
    static func getModelCapabilities(_ modelName: String) -> String {
        switch modelName {
        case "MobileNetV2":
            return """
            This model can detect around 1000 common objects including:
            - Electronic devices (phones, laptops, TVs)
            - Furniture (chairs, tables, sofas)
            - Household items (cups, bottles, books)
            - Clothing items (shirts, shoes, hats)
            - And many more everyday objects
            
            It works best with well-lit, clearly visible objects that are centered in the frame.
            """
        default:
            return "Unknown model capabilities"
        }
    }
    
    /// Returns loading instructions for developers
    static func getModelLoadingInstructions() -> String {
        return """
        To use the pre-trained MobileNetV2 model:
        
        1. Download the model from Apple's ML Model Gallery or convert using coremltools:
           https://developer.apple.com/machine-learning/models/
           
        2. Add the .mlmodel file to your Xcode project
           
        3. Xcode will automatically compile it to .mlmodelc format
           
        4. Make sure the model is included in your target's "Copy Bundle Resources" build phase
           
        5. The VisionManager class will look for "MobileNetV2.mlmodelc" in the app bundle
        """
    }
} 