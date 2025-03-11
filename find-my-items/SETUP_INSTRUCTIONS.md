# Setup Instructions for Find My Items

## Camera Permissions Setup

To ensure the app has proper camera access, you need to configure the Info.plist file with the correct usage descriptions:

1. Open your project in Xcode
2. Find the Info.plist file in the Project Navigator
3. Add the following keys with appropriate descriptions:

```
NSCameraUsageDescription - "Find My Items needs camera access to help you locate objects by analyzing what the camera sees."
NSMicrophoneUsageDescription - "Find My Items may use the microphone for audio feedback when items are found."
```

If you're using the Info.plist we provided, make sure it's properly included in your project:

1. Check that the file is in your project's target membership
2. Ensure it's listed in "Build Phases" > "Copy Bundle Resources"

## Camera Usage

The app requires a device with a camera. It won't work properly in the iOS Simulator without camera access. It's best to test on a physical iOS device.

## Performance Considerations

- The object detection features use significant CPU/GPU resources
- Battery usage will be higher when using the app for extended periods
- Ensure your device has sufficient battery when using the app

## Additional Requirements

As we build out more features, additional permissions might be required:
- Photo Library access (for saving photos of found items)
- Location Services (for AR features)
- Notifications (for alerts when items are found)

These will be added in future updates and will require additional Info.plist entries. 