# Fly2Map Tracker - Flutter Object Detection & Tracking App

A professional Flutter Android application that uses camera input to detect and track 3 objects (apple, orange, banana) using YOLOv12n with BoT-SORT tracking, 3D coordinate estimation, OCR via Gemini 2.0 Flash, and Firebase real-time data storage.

## Features

- **Real-time Object Detection**: Uses YOLOv12n TensorFlow Lite model pretrained on COCO dataset
- **Object Tracking**: Implements BoT-SORT algorithm for robust multi-object tracking
- **3D Coordinate Estimation**: Calculates real-world 3D coordinates using camera intrinsics
- **OCR Integration**: Detects codes/numbers on objects using Gemini 2.0 Flash API
- **Firebase Integration**: Real-time data storage and tracking history
- **Professional UI**: Clean interface with color-coded bounding boxes and real-time statistics

## Supported Objects

- 🍌 **Banana** (COCO class 46) - Yellow bounding box
- 🍎 **Apple** (COCO class 47) - Red bounding box
- 🍊 **Orange** (COCO class 49) - Orange bounding box

## Setup Instructions

### 1. Prerequisites

- Flutter SDK (>=3.10.0)
- Dart SDK (>=3.0.0)
- Android Studio with Android SDK
- Firebase project
- Google AI Studio account (for Gemini API)

### 2. Clone and Install Dependencies

```bash
cd fly2map_tracker
flutter pub get
```

### 3. Place the YOLO Model

**IMPORTANT**: Place your `yolo12n_float32.tflite` model file in:
```
assets/models/yolo12n_float32.tflite
```

Create the directories if they don't exist:
```bash
mkdir -p assets/models
# Copy your yolo12n_float32.tflite file to assets/models/
```

### 4. Firebase Setup

1. **Create Firebase Project**:
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Create a new project
   - Enable Firestore Database
   - Enable Firebase Storage

2. **Add Android App**:
   - Register your Android app with package name `com.fly2map.tracker`
   - Download `google-services.json`
   - Place it in `android/app/google-services.json`

3. **Configure Firestore Rules**:
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /tracked_objects/{document} {
         allow read, write: if true; // Adjust based on your security needs
       }
     }
   }
   ```

4. **Configure Storage Rules**:
   ```javascript
   rules_version = '2';
   service firebase.storage {
     match /b/{bucket}/o {
       match /cropped_images/{allPaths=**} {
         allow read, write: if true; // Adjust based on your security needs
       }
     }
   }
   ```

### 5. Gemini API Setup

1. **Get API Key**:
   - Go to [Google AI Studio](https://aistudio.google.com/)
   - Create or select a project
   - Generate an API key

2. **Configure API Key**:
   - Open `lib/services/gemini_service.dart`
   - Replace `'YOUR_GEMINI_API_KEY_HERE'` with your actual API key:
   ```dart
   static const String _apiKey = 'your_actual_api_key_here';
   ```

### 6. Build and Run

```bash
# Generate JSON serialization code
flutter packages pub run build_runner build

# Run on connected Android device
flutter run
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── detection.dart        # Detection and tracking models
│   └── detection.g.dart      # Generated JSON serialization
├── screens/                  # UI screens
│   ├── splash_screen.dart    # Splash screen with app logo
│   └── camera_screen.dart    # Main camera and detection screen
├── services/                 # Core services
│   ├── detection_service.dart     # YOLO model inference
│   ├── tracking_service.dart      # BoT-SORT tracking
│   ├── distance_estimation_service.dart # 3D coordinate calculation
│   ├── gemini_service.dart        # OCR via Gemini API
│   └── firebase_service.dart      # Firebase integration
└── widgets/                  # UI components
    ├── detection_overlay.dart     # Detection visualization
    └── bounding_box.dart         # Bounding box widget
```

## How It Works

1. **Detection**: Camera frames are processed by YOLOv12n model every 100ms
2. **Tracking**: BoT-SORT algorithm associates detections across frames
3. **3D Estimation**: Uses object size and camera intrinsics to estimate distance and 3D position
4. **OCR**: When new objects are detected, cropped images are sent to Gemini for code detection
5. **Firebase**: Real-time data storage of tracking information and coordinate history

## Data Flow

### New Object Detection:
1. Object detected → Assign tracking ID → Crop image → OCR with Gemini → Send full data to Firebase

### Existing Object Update:
1. Object tracked → Update 3D coordinates → Send coordinate update to Firebase

### Firebase Data Structure:
```json
{
  "trackId": 1,
  "label": "banana",
  "confidence": 0.95,
  "firstDetected": "2025-01-01T12:00:00Z",
  "lastSeen": "2025-01-01T12:00:05Z",
  "detectedCode": "HA8-65",
  "currentCoordinates": {
    "x": 1.2,
    "y": 3.4,
    "z": 0.5,
    "timestamp": "2025-01-01T12:00:05Z"
  },
  "coordinateHistory": [...],
  "croppedImageUrl": "https://..."
}
```

## Customization

### Camera Parameters
Adjust camera intrinsics in `distance_estimation_service.dart`:
```dart
static const double cameraHFovDeg = 42.08;
static const double cameraFocalLengthMM = 4.0;
static const double sensorWidthMM = 5.5385;
```

### Detection Confidence
Modify thresholds in `detection_service.dart`:
```dart
static const double confidenceThreshold = 0.5;
static const double iouThreshold = 0.45;
```

### Object Heights
Update assumed object heights in `distance_estimation_service.dart`:
```dart
static const Map<String, double> assumedRealHeightM = {
  "banana": 0.19,
  "apple": 0.09,
  "orange": 0.075,
};
```

## Troubleshooting

### Model Loading Issues
- Ensure `yolo12n_float32.tflite` is in `assets/models/`
- Check model is added to `pubspec.yaml` assets
- Verify model format is TensorFlow Lite float32

### Firebase Connection
- Verify `google-services.json` placement
- Check Firebase project configuration
- Ensure Firestore and Storage are enabled

### Gemini API Issues
- Verify API key is correct
- Check API quota and billing
- Ensure Gemini 2.0 Flash is available in your region

### Camera Permissions
- Grant camera permissions when prompted
- Check Android manifest permissions

## Performance Tips

- **Frame Rate**: Adjust detection interval in `camera_screen.dart`
- **Model Optimization**: Use quantized models for better performance
- **Firebase Batching**: Coordinate updates are batched for efficiency
- **Memory Management**: Old coordinate history is automatically cleaned

## License

This project is created for demonstration purposes. Please ensure you have proper licenses for:
- YOLOv12n model usage
- COCO dataset usage
- Gemini API usage
- Firebase usage

## Support

For issues and questions:
1. Check the troubleshooting section
2. Verify all setup steps are completed
3. Test on a physical Android device (recommended over emulator)

