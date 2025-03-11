//
//  VisionManager.swift
//  find-my-items
//
//  Created by Quang Tran Minh on 11/3/25.
//

import Vision
import CoreML
import UIKit

/// Class that manages Vision and CoreML for object detection
class VisionManager {
    // MLModel and VNCoreMLModel for object detection
    private var objectDetectionModel: MLModel?
    private var visionModel: VNCoreMLModel?
    
    // Vision request for object detection
    private var objectDetectionRequest: VNCoreMLRequest?
    
    // Completion handler for detection results
    typealias DetectionResultsHandler = ([RecognizedItem]?, Error?) -> Void
    
    // Current detection results handler
    private var currentResultsHandler: DetectionResultsHandler?
    
    // Initialize with a model name
    init(modelName: String) {
        setupVisionWithModelNamed(modelName)
    }
    
    // Set up Vision with a Core ML model
    private func setupVisionWithModelNamed(_ modelName: String) {
        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") else {
            print("Failed to find model file: \(modelName).mlmodelc")
            return
        }
        
        do {
            objectDetectionModel = try MLModel(contentsOf: modelURL)
            visionModel = try VNCoreMLModel(for: objectDetectionModel!)
            
            objectDetectionRequest = VNCoreMLRequest(model: visionModel!) { [weak self] request, error in
                self?.processDetectionResults(request: request, error: error)
            }
            
            // Configure the request for optimal performance
            objectDetectionRequest?.imageCropAndScaleOption = .scaleFill
        } catch {
            print("Failed to load Vision model: \(error)")
        }
    }
    
    // Process a camera frame for object detection
    func processFrame(_ pixelBuffer: CVPixelBuffer, completion: @escaping DetectionResultsHandler) {
        // Store completion handler
        currentResultsHandler = completion
        
        // Create a request handler
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        // Perform the request
        guard let request = objectDetectionRequest else {
            completion(nil, NSError(domain: "VisionManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Vision model not loaded"]))
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }
    }
    
    // Process detection results from the Vision request
    private func processDetectionResults(request: VNRequest, error: Error?) {
        // Get the completion handler
        guard let completion = currentResultsHandler else { return }
        
        // Handle errors
        if let error = error {
            DispatchQueue.main.async {
                completion(nil, error)
            }
            return
        }
        
        // Process results
        if let results = request.results as? [VNRecognizedObjectObservation] {
            let recognizedItems = results.compactMap { observation -> RecognizedItem? in
                // Get the top classification
                guard let topLabelObservation = observation.labels.first else {
                    return nil
                }
                
                // Create a recognized item
                return RecognizedItem(
                    label: topLabelObservation.identifier,
                    confidence: topLabelObservation.confidence,
                    boundingBox: observation.boundingBox
                )
            }
            
            // Return results on the main thread
            DispatchQueue.main.async {
                completion(recognizedItems, nil)
            }
        } else {
            DispatchQueue.main.async {
                completion([], nil)
            }
        }
    }
} 