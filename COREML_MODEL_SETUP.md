# Setting Up CoreML Models for Find My Items

This document explains how to add the necessary CoreML models to enable object detection in the Find My Items app.

## Required Models

The app requires a pre-trained object detection model. We recommend using MobileNetV2, which can recognize a wide range of common household objects while maintaining good performance on mobile devices.

## Option 1: Using Apple's Core ML Models

1. Visit Apple's [Core ML Models](https://developer.apple.com/machine-learning/models/) page
2. Download the MobileNetV2 model (or another object detection model of your choice)
3. Add the downloaded `.mlmodel` file to your Xcode project:
   - Drag and drop the file into your Xcode project
   - Make sure "Copy items if needed" is checked
   - Add to the "find-my-items" target
   - Xcode will automatically compile the model to the optimized `.mlmodelc` format

## Option 2: Converting Models from Other Formats

If you have another model in a different format (e.g., TensorFlow, PyTorch), you can convert it using Apple's `coremltools` Python package:

1. Install coremltools: `pip install coremltools`
2. Convert your model using the appropriate converter
3. Example conversion script for TensorFlow models:

```python
import coremltools as ct

# Load your model
tfmodel = ... # Your TensorFlow model loading code

# Convert to Core ML format
mlmodel = ct.convert(tfmodel, 
                    inputs=[ct.ImageType(name="image", shape=(1, 224, 224, 3), 
                                         scale=1/255.0)],
                    classifier_config=ct.ClassifierConfig(class_labels))

# Save the model
mlmodel.save("YourModel.mlmodel")
```

4. Add the resulting `.mlmodel` file to your Xcode project

## Configuring the App to Use Your Model

The app is configured to look for a model named "MobileNetV2" by default. If your model has a different name, you'll need to update the following code in `CameraViewModel.swift`:

```swift
// Change this line:
self.visionManager = VisionManager(modelName: "MobileNetV2")

// To use your model name:
self.visionManager = VisionManager(modelName: "YourModelName")
```

## Testing the Model

1. Install the app on a physical device (the simulator doesn't support camera)
2. Grant camera permissions when prompted
3. Enter a search term like "phone" or "laptop"
4. Point the camera at objects around you
5. The app should identify matching objects and highlight them

## Performance Notes

- Object detection is computationally intensive and will impact battery life
- The app uses frame skipping (processing every 5th frame) to improve performance
- You can adjust this in `CameraViewModel.swift` by changing `frameSkipCount`
- Consider testing different models to find the right balance of accuracy vs. performance for your needs 