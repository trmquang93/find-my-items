//
//  DetectionOverlayView.swift
//  find-my-items
//
//  Created by Quang Tran Minh on 11/3/25.
//

import SwiftUI

/// A view that displays overlays for detected objects
struct DetectionOverlayView: View {
    /// The detected objects to display
    var detectedObjects: [RecognizedItem]
    
    /// The size of the view containing this overlay
    var viewSize: CGSize
    
    var body: some View {
        ZStack {
            // Render each detected object
            ForEach(detectedObjects) { object in
                BoundingBoxView(
                    recognizedItem: object,
                    viewSize: viewSize
                )
                .transition(.opacity)
                .id(object.id)
            }
        }
    }
}

/// A view that displays a bounding box for a detected object
struct BoundingBoxView: View {
    /// The recognized item to display
    let recognizedItem: RecognizedItem
    
    /// The size of the view containing this bounding box
    let viewSize: CGSize
    
    /// Whether the label is expanded to show details
    @State private var isLabelExpanded = false
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Bounding box
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(boxColor, lineWidth: 3)
                .frame(
                    width: viewSize.width * recognizedItem.boundingBox.width,
                    height: viewSize.height * recognizedItem.boundingBox.height
                )
            
            // Label background
            if isLabelExpanded {
                boxColor.opacity(0.8)
                    .frame(width: labelWidth, height: 60)
                    .cornerRadius(8)
                    .offset(y: -30)
            } else {
                boxColor.opacity(0.8)
                    .frame(width: labelWidth, height: 30)
                    .cornerRadius(8)
                    .offset(y: -30)
            }
            
            // Label text
            VStack(alignment: .leading, spacing: 2) {
                Text(recognizedItem.label)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                if isLabelExpanded {
                    Text("Confidence: \(Int(recognizedItem.confidence * 100))%")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                    
                    if recognizedItem.matchType == .potentialLocation,
                       let locationDesc = recognizedItem.locationDescription {
                        Text("Might be \(locationDesc)")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .offset(y: -30)
        }
        .position(
            x: viewSize.width * recognizedItem.boundingBox.midX,
            y: viewSize.height * recognizedItem.boundingBox.midY
        )
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isLabelExpanded.toggle()
            }
        }
    }
    
    /// The width of the label
    private var labelWidth: CGFloat {
        let minWidth: CGFloat = 100
        let labelLength = CGFloat(recognizedItem.label.count) * 10
        return max(minWidth, labelLength)
    }
    
    /// The color of the bounding box, based on match type
    private var boxColor: Color {
        switch recognizedItem.matchType {
        case .exactMatch:
            return Color.green
        case .similarItem:
            return Color.blue
        case .potentialLocation:
            return Color.orange
        }
    }
}

#Preview {
    // Sample recognized items for preview
    let sampleItems = [
        RecognizedItem(
            label: "Laptop",
            confidence: 0.92,
            boundingBox: CGRect(x: 0.2, y: 0.3, width: 0.3, height: 0.2),
            matchType: .exactMatch
        ),
        RecognizedItem(
            label: "Coffee Cup",
            confidence: 0.87,
            boundingBox: CGRect(x: 0.6, y: 0.5, width: 0.15, height: 0.2),
            matchType: .similarItem
        ),
        RecognizedItem(
            label: "Desk",
            confidence: 0.78,
            boundingBox: CGRect(x: 0.3, y: 0.7, width: 0.4, height: 0.25),
            matchType: .potentialLocation,
            locationDescription: "on the desk"
        )
    ]
    
    ZStack {
        Color.black.edgesIgnoringSafeArea(.all)
        DetectionOverlayView(
            detectedObjects: sampleItems,
            viewSize: CGSize(width: 390, height: 844)
        )
    }
} 