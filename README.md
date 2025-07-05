# Realtime Object Detection App

![](https://github.com/mohitj2401/realtime-object-detection/blob/master/realtime_obj_detection.gif)

## :dart: About ##

Welcome to our cutting-edge Real-Time Object Detection app, built using Flutter and TensorFlow Lite (TFLite). This application is designed to provide an intuitive and efficient way to detect objects in real-time using your device's camera. Whether you are a developer, a tech enthusiast, or simply curious about AI-powered applications, our app offers a seamless and interactive experience in exploring the potential of object detection.


## :rocket: Technologies ##

The following tools were used in this project:

- [Tflite](https://www.tensorflow.org/lite)
- [Flutter](https://flutter.dev/)


## :checkered_flag: Starting ##

```bash
# Clone this project
$ git clone https://github.com/mohitj2401/realtime-object-detection

# Access
$ cd realtime-object-detection

# Install dependencies
$ flutter pub get

# Run
$ flutter run
```

---

## :warning: Android Gradle & tflite_v2 Namespace Issue

If you see an error like:

```
Namespace not specified. Specify a namespace in the module's build file: .../tflite_v2-1.0.0/android/build.gradle
```

### Solution
1. Go to:
   `C:\Users\<your-username>\AppData\Local\Pub\Cache\hosted\pub.dev\tflite_v2-1.0.0\android\build.gradle`
2. Add this line inside the `android { ... }` block:
   ```gradle
   namespace 'sq.flutter.tflite'
   ```
3. Save the file and re-run:
   ```sh
   flutter clean
   flutter pub get
   flutter run
   ```

> **Note:** This is a temporary fix. If you update or clean your pub cache, you may need to repeat this step. For a permanent solution, fork the package or ask the maintainer to add the namespace property.

---

## :bulb: Troubleshooting
- Ensure your Android emulator or device is running and accessible.
- If you see Gradle or Java compatibility errors, update your Gradle version in `android/gradle/wrapper/gradle-wrapper.properties` and plugin versions in `android/settings.gradle`.
- For camera permission issues, check your AndroidManifest.xml.

## :file_folder: Assets
- Place your TFLite model and labelmap in the `assets/` directory.
- Ensure `pubspec.yaml` includes:
  ```yaml
  assets:
    - assets/
  ```

## License
This project is for educational purposes.
