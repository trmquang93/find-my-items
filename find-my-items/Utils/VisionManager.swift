//
//  VisionManager.swift
//  find-my-items
//
//  Created by Quang Tran Minh on 11/3/25.
//

import CoreML
import UIKit
import Vision

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
        // First try to find the compiled model (.mlmodelc)
        var modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc")

        // If compiled model not found, try the original .mlmodel file
        if modelURL == nil {
            modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodel")
        }

        // Still couldn't find the model, log error and throw an assertion in debug
        guard let finalModelURL = modelURL else {
            print("ERROR: Failed to find model file: \(modelName).mlmodel or \(modelName).mlmodelc")
            #if DEBUG
                assertionFailure("ML Model not found: \(modelName)")
            #endif
            return
        }

        do {
            print("Starting model initialization for: \(modelName)")

            // If we have a .mlmodel file, compile it at runtime
            if finalModelURL.pathExtension == "mlmodel" {
                print("Compiling ML model at runtime: \(modelName)")
                let compiledURL = try MLModel.compileModel(at: finalModelURL)
                objectDetectionModel = try MLModel(contentsOf: compiledURL)
                print("Successfully compiled model")
            } else {
                // Otherwise load the pre-compiled model
                print("Loading pre-compiled model: \(modelName)")
                objectDetectionModel = try MLModel(contentsOf: finalModelURL)
            }

            guard let model = objectDetectionModel else {
                print("ERROR: Failed to initialize MLModel")
                return
            }

            print("Creating Vision model wrapper")
            visionModel = try VNCoreMLModel(for: model)

            // Create and configure the classification request
            print("Configuring Vision request")
            objectDetectionRequest = VNCoreMLRequest(model: visionModel!) {
                [weak self] request, error in
                self?.processDetectionResults(request: request, error: error)
            }

            // Configure the request for optimal performance
            objectDetectionRequest?.imageCropAndScaleOption = .centerCrop

            // Configure for real-time performance
            // objectDetectionRequest?.usesCPUOnly = false // Use GPU if available
            objectDetectionRequest?.revision = VNCoreMLRequestRevision1

            print("Successfully loaded Vision classification model: \(modelName)")
            print("Model configuration:")
            print(
                "- Image crop and scale: \(objectDetectionRequest?.imageCropAndScaleOption.rawValue ?? 0)"
            )
            // print("- Uses CPU only: \(objectDetectionRequest?.usesCPUOnly ?? true)")
            print("- Request revision: \(objectDetectionRequest?.revision ?? 0)")

            // Print model metadata if available
            let metadata = model.modelDescription.metadata
            print("Model metadata:")
            print("- Author: \(metadata[.author] ?? "Unknown")")
            print("- Description: \(metadata[.description] ?? "None")")
            print("- Version: \(metadata[.versionString] ?? "Unknown")")

        } catch {
            print("ERROR: Failed to load Vision model: \(error.localizedDescription)")
            print("Error details: \(error)")
        }
    }

    // Process a camera frame for object detection
    func processFrame(_ pixelBuffer: CVPixelBuffer, completion: @escaping DetectionResultsHandler) {
        // Store completion handler
        currentResultsHandler = completion

        // Get the orientation of the device
        let orientation = CGImagePropertyOrientation(UIDevice.current.orientation)

        // Create a request handler with orientation
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: orientation,
            options: [
                VNImageOption.ciContext: CIContext()
                    // VNImageOption.preferBackgroundProcessing: true
            ]
        )

        // Check if model and request are properly initialized
        guard let request = objectDetectionRequest else {
            let error = NSError(
                domain: "VisionManager", code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Vision model not loaded or initialization failed"
                ])
            print("ERROR: Detection failed - \(error.localizedDescription)")
            DispatchQueue.main.async {
                completion(nil, error)
            }
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Perform the request
                try handler.perform([request])

                // Log the request completion
                print("Vision request completed successfully")
            } catch {
                print("ERROR: Vision request failed - \(error.localizedDescription)")
                print("Error details: \(error)")
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
            print("ERROR: Processing results failed - \(error.localizedDescription)")
            DispatchQueue.main.async {
                completion(nil, error)
            }
            return
        }

        // Process classification results
        if let results = request.results as? [VNClassificationObservation] {
            // Filter results with confidence above threshold (adjusted for better precision)
            let significantResults = results.filter { $0.confidence > 0.15 }  // Increased threshold for better precision

            print("Raw classification results:")
            results.prefix(5).forEach { result in
                print("- \(result.identifier): \(Int(result.confidence * 100))%")
            }

            // Convert classification results to RecognizedItems
            let recognizedItems = significantResults.map { observation -> RecognizedItem in
                // For classification results, we use the full frame as the bounding box
                let fullFrameBox = CGRect(x: 0, y: 0, width: 1, height: 1)

                return RecognizedItem(
                    label: observation.identifier,
                    confidence: Float(observation.confidence),
                    boundingBox: fullFrameBox
                )
            }

            // Log the filtered results
            print("\nSignificant results (confidence > 15%):")
            for item in recognizedItems {
                print("- \(item.label): \(Int(item.confidence * 100))%")
            }

            // Return results on the main thread
            DispatchQueue.main.async {
                completion(recognizedItems, nil)
            }
        } else {
            print("No classification results found - Result type: \(type(of: request.results))")
            print("Number of results: \(request.results?.count ?? 0)")
            DispatchQueue.main.async {
                completion([], nil)
            }
        }
    }
}

// Helper extension to convert UIDeviceOrientation to CGImagePropertyOrientation
extension CGImagePropertyOrientation {
    init(_ deviceOrientation: UIDeviceOrientation) {
        switch deviceOrientation {
        case .portraitUpsideDown: self = .left
        case .landscapeLeft: self = .up
        case .landscapeRight: self = .down
        case .portrait: self = .right
        default: self = .right
        }
    }
}
