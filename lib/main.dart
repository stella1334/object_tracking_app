// import 'package:flutter/material.dart';
// import 'package:camera/camera.dart';
// import 'package:flutter/widgets.dart';
// import 'package:tflite_v2/tflite_v2.dart';
// import 'dart:math';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   final cameras = await availableCameras();
//   runApp(MyApp(cameras: cameras));
// }

// class MyApp extends StatelessWidget {
//   final List<CameraDescription> cameras;

//   const MyApp({Key? key, required this.cameras});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       home: RealTimeObjectDetection(
//         cameras: cameras,
//       ),
//     );
//   }
// }

// // Simple tracking data structure
// class TrackedObject {
//   int id;
//   String className;
//   double confidence;
//   Rect rect;
//   int framesSinceUpdate;
//   List<Rect> history; // For velocity calculation
//   Color color;

//   TrackedObject({
//     required this.id,
//     required this.className,
//     required this.confidence,
//     required this.rect,
//     this.framesSinceUpdate = 0,
//     List<Rect>? history,
//     required this.color,
//   }) : history = history ?? [];
// }

// // Simple object tracker
// class SimpleTracker {
//   List<TrackedObject> trackedObjects = [];
//   int nextId = 1;
//   static const double IOU_THRESHOLD = 0.3;
//   static const int MAX_FRAMES_WITHOUT_UPDATE = 10;

//   // Only track these specific classes
//   static const Set<String> ALLOWED_CLASSES = {
//     'apple',
//     'orange',
//     'banana'
//   };

//   // Predefined colors for different tracks
//   static const List<Color> TRACK_COLORS = [
//     Colors.red,
//     Colors.blue,
//     Colors.green,
//     Colors.orange,
//     Colors.purple,
//     Colors.yellow,
//     Colors.pink,
//     Colors.cyan,
//   ];

//   double calculateIOU(Rect rect1, Rect rect2) {
//     final intersection = rect1.intersect(rect2);
//     if (intersection.isEmpty) return 0.0;

//     final intersectionArea = intersection.width * intersection.height;
//     final union = rect1.width * rect1.height + rect2.width * rect2.height - intersectionArea;

//     return union > 0 ? intersectionArea / union : 0.0;
//   }

//   List<TrackedObject> update(List<dynamic> recognitions, double screenW, double screenH) {
//     // Filter recognitions to only include allowed classes
//     List<dynamic> filteredRecognitions = recognitions.where((rec) {
//       String className = rec["detectedClass"].toString().toLowerCase();
//       return ALLOWED_CLASSES.contains(className);
//     }).toList();

//     // Convert filtered recognitions to Rect objects
//     List<Map<String, dynamic>> detections = filteredRecognitions.map((rec) {
//       var x = rec["rect"]["x"] * screenW;
//       var y = rec["rect"]["y"] * screenH;
//       double w = rec["rect"]["w"] * screenW;
//       double h = rec["rect"]["h"] * screenH;

//       return {
//         'rect': Rect.fromLTWH(x, y, w, h),
//         'class': rec["detectedClass"].toString().toLowerCase(),
//         'confidence': rec["confidenceInClass"],
//       };
//     }).toList();

//     // Mark all tracked objects as not updated
//     for (var obj in trackedObjects) {
//       obj.framesSinceUpdate++;
//     }

//     // Match detections with existing tracks
//     List<bool> detectionMatched = List.filled(detections.length, false);

//     for (int i = 0; i < detections.length; i++) {
//       if (detectionMatched[i]) continue;

//       double bestIOU = 0;
//       TrackedObject? bestMatch;

//       for (var trackedObj in trackedObjects) {
//         if (trackedObj.className == detections[i]['class']) {
//           double iou = calculateIOU(trackedObj.rect, detections[i]['rect']);
//           if (iou > bestIOU && iou > IOU_THRESHOLD) {
//             bestIOU = iou;
//             bestMatch = trackedObj;
//           }
//         }
//       }

//       if (bestMatch != null) {
//         // Update existing track
//         bestMatch.rect = detections[i]['rect'];
//         bestMatch.confidence = detections[i]['confidence'];
//         bestMatch.framesSinceUpdate = 0;
//         bestMatch.history.add(bestMatch.rect);
//         if (bestMatch.history.length > 5) {
//           bestMatch.history.removeAt(0);
//         }
//         detectionMatched[i] = true;
//       }
//     }

//     // Create new tracks for unmatched detections (only for allowed classes)
//     for (int i = 0; i < detections.length; i++) {
//       if (!detectionMatched[i] && ALLOWED_CLASSES.contains(detections[i]['class'])) {
//         trackedObjects.add(TrackedObject(
//           id: nextId++,
//           className: detections[i]['class'],
//           confidence: detections[i]['confidence'],
//           rect: detections[i]['rect'],
//           color: getColorForClass(detections[i]['class']),
//         ));
//       }
//     }

//     // Remove tracks that haven't been updated for too long
//     trackedObjects.removeWhere((obj) => obj.framesSinceUpdate > MAX_FRAMES_WITHOUT_UPDATE);

//     return trackedObjects;
//   }

//   // Get color based on fruit class
//   Color getColorForClass(String className) {
//     switch (className.toLowerCase()) {
//       case 'banana':
//         return Colors.yellow;
//       case 'apple':
//         return Colors.red;
//       case 'orange':
//         return Colors.orange;
//       default:
//         return Colors.grey;
//     }
//   }
// }

// class RealTimeObjectDetection extends StatefulWidget {
//   final List<CameraDescription> cameras;

//   RealTimeObjectDetection({required this.cameras});

//   @override
//   _RealTimeObjectDetectionState createState() =>
//       _RealTimeObjectDetectionState();
// }

// class _RealTimeObjectDetectionState extends State<RealTimeObjectDetection> {
//   late CameraController _controller;
//   bool isModelLoaded = false;
//   bool isDetecting = false; // Add flag to prevent concurrent inference
//   List<dynamic>? recognitions;
//   List<TrackedObject> trackedObjects = [];
//   int imageHeight = 0;
//   int imageWidth = 0;
//   SimpleTracker tracker = SimpleTracker();

//   @override
//   void initState() {
//     super.initState();
//     loadModel();
//     initializeCamera(null);
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   Future<void> loadModel() async {
//     String? res = await Tflite.loadModel(
//       model: 'assets/detect.tflite',
//       labels: 'assets/labelmap.txt',
//     );
//     setState(() {
//       isModelLoaded = res != null;
//     });
//   }

//   void toggleCamera() {
//     final lensDirection = _controller.description.lensDirection;
//     CameraDescription newDescription;
//     if (lensDirection == CameraLensDirection.front) {
//       newDescription = widget.cameras.firstWhere((description) =>
//           description.lensDirection == CameraLensDirection.back);
//     } else {
//       newDescription = widget.cameras.firstWhere((description) =>
//           description.lensDirection == CameraLensDirection.front);
//     }

//     if (newDescription != null) {
//       initializeCamera(newDescription);
//     } else {
//       print('Asked camera not available');
//     }
//   }

//   void initializeCamera(description) async {
//     if (description == null) {
//       _controller = CameraController(
//         widget.cameras[0],
//         ResolutionPreset.high,
//         enableAudio: false,
//       );
//     } else {
//       _controller = CameraController(
//         description,
//         ResolutionPreset.high,
//         enableAudio: false,
//       );
//     }

//     await _controller.initialize();

//     if (!mounted) {
//       return;
//     }
//     _controller.startImageStream((CameraImage image) {
//       // Only run inference if model is loaded and not currently detecting
//       if (isModelLoaded && !isDetecting) {
//         runModel(image);
//       }
//     });
//     setState(() {});
//   }

//   void runModel(CameraImage image) async {
//     if (image.planes.isEmpty || isDetecting) return;

//     // Set detecting flag to prevent concurrent inference
//     setState(() {
//       isDetecting = true;
//     });

//     try {
//       var recognitions = await Tflite.detectObjectOnFrame(
//         bytesList: image.planes.map((plane) => plane.bytes).toList(),
//         model: 'SSDMobileNet',
//         imageHeight: image.height,
//         imageWidth: image.width,
//         imageMean: 127.5,
//         imageStd: 127.5,
//         numResultsPerClass: 1,
//         threshold: 0.4,
//       );

//       if (recognitions != null && mounted) {
//         // Update tracker with new detections
//         List<TrackedObject> updatedTracks = tracker.update(
//           recognitions,
//           MediaQuery.of(context).size.width,
//           MediaQuery.of(context).size.height * 0.8
//         );

//         setState(() {
//           this.recognitions = recognitions;
//           this.trackedObjects = updatedTracks;
//         });
//       }
//     } catch (e) {
//       print('Error during inference: $e');
//     } finally {
//       // Always reset the detecting flag
//       if (mounted) {
//         setState(() {
//           isDetecting = false;
//         });
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (!_controller.value.isInitialized) {
//       return Container();
//     }
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Real-time Object Detection with Tracking'),
//       ),
//       body: Column(
//         children: [
//           Container(
//             width: MediaQuery.of(context).size.width,
//             height: MediaQuery.of(context).size.height * 0.8,
//             child: Stack(
//               children: [
//                 CameraPreview(_controller),
//                 if (trackedObjects.isNotEmpty)
//                   TrackingBoundingBoxes(
//                     trackedObjects: trackedObjects,
//                     screenH: MediaQuery.of(context).size.height * 0.8,
//                     screenW: MediaQuery.of(context).size.width,
//                   ),
//               ],
//             ),
//           ),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               IconButton(
//                   onPressed: () {
//                     toggleCamera();
//                   },
//                   icon: Icon(
//                     Icons.camera_front,
//                     size: 30,
//                   ))
//             ],
//           )
//         ],
//       ),
//     );
//   }
// }

// class TrackingBoundingBoxes extends StatelessWidget {
//   final List<TrackedObject> trackedObjects;
//   final double screenH;
//   final double screenW;

//   TrackingBoundingBoxes({
//     required this.trackedObjects,
//     required this.screenH,
//     required this.screenW,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Stack(
//       children: trackedObjects.map((obj) {
//         return Positioned(
//           left: obj.rect.left,
//           top: obj.rect.top,
//           width: obj.rect.width,
//           height: obj.rect.height,
//           child: Container(
//             decoration: BoxDecoration(
//               border: Border.all(
//                 color: obj.color,
//                 width: 3,
//               ),
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Container(
//                   padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
//                   decoration: BoxDecoration(
//                     color: obj.color,
//                   ),
//                   child: Text(
//                     "ID:${obj.id} ${obj.className} ${(obj.confidence * 100).toStringAsFixed(0)}% H:${obj.rect.height.ceil()}px",
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 12,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         );
//       }).toList(),
//     );
//   }
// }

// // Keep original BoundingBoxes for comparison if needed
// class BoundingBoxes extends StatelessWidget {
//   final List<dynamic> recognitions;
//   final double previewH;
//   final double previewW;
//   final double screenH;
//   final double screenW;

//   BoundingBoxes({
//     required this.recognitions,
//     required this.previewH,
//     required this.previewW,
//     required this.screenH,
//     required this.screenW,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Stack(
//       children: recognitions.map((rec) {
//         var x = rec["rect"]["x"] * screenW;
//         var y = rec["rect"]["y"] * screenH;
//         double w = rec["rect"]["w"] * screenW;
//         double h = rec["rect"]["h"] * screenH;

//         return Positioned(
//           left: x,
//           top: y,
//           width: w,
//           height: h,
//           child: Container(
//             decoration: BoxDecoration(
//               border: Border.all(
//                 color: Colors.red,
//                 width: 3,
//               ),
//             ),
//             child: Text(
//               "${rec["detectedClass"]} ${(rec["confidenceInClass"] * 100).toStringAsFixed(0)}% Width:${(w).ceil()} Heght: ${h.ceil()}",
//               style: TextStyle(
//                 color: Colors.red,
//                 fontSize: 15,
//                 background: Paint()..color = Colors.black,
//               ),
//             ),
//           ),
//         );
//       }).toList(),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:realtime_obj_detection/firebase_options.dart';
import 'package:realtime_obj_detection/services/cloud_services/object_handler.dart';
import 'package:realtime_obj_detection/utils/throttler.dart';
import 'package:tflite_v2/tflite_v2.dart';
import 'dart:math';
import 'services/coordinate_estimation_service.dart'; // Import the service
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
    // App can still run with local data fallback
  }

  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MyApp({Key? key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RealTimeObjectDetection(
        cameras: cameras,
      ),
    );
  }
}

// Enhanced tracking data structure with 3D coordinates
class TrackedObject {
  int id;
  String className;
  double confidence;
  Rect rect;
  int framesSinceUpdate;
  List<Rect> history;
  Color color;

  // 3D positioning data
  double? distance;
  double? horizontalAngle;
  double? verticalAngle;
  double? x; // Lateral position
  double? y; // Forward distance
  double? z; // Vertical position

  // Screen dimensions for calculation
  double? screenWidth;
  double? screenHeight;

  TrackedObject({
    required this.id,
    required this.className,
    required this.confidence,
    required this.rect,
    this.framesSinceUpdate = 0,
    List<Rect>? history,
    required this.color,
    this.distance,
    this.horizontalAngle,
    this.verticalAngle,
    this.x,
    this.y,
    this.z,
    this.screenWidth,
    this.screenHeight,
  }) : history = history ?? [];

  // Calculate 3D coordinates using the estimation service
  void calculate3DCoordinates() {
    if (screenWidth == null || screenHeight == null) return;

    // Calculate center point of bounding box
    double centerX = rect.left + (rect.width / 2);
    double centerY = rect.top + (rect.height / 2);

    // Estimate distance using object height
    distance = CoordinateEstimationService.estimateDistanceFromBbox(
      CoordinateEstimationService.getAssumedHeight(className),
      rect.height,
      screenWidth!,
    );

    if (distance != null) {
      // Calculate angles from center of image
      final angles = CoordinateEstimationService.calculateAngles(
        centerX,
        centerY,
        imageWidthPx: screenWidth!,
        imageHeightPx: screenHeight!,
      );

      horizontalAngle = angles.$1;
      verticalAngle = angles.$2;

      // Calculate 3D coordinates
      final coords = CoordinateEstimationService.calculateCoordinates3D(
        distance!,
        horizontalAngle!,
        verticalAngle!,
      );

      x = coords.$1;
      y = coords.$2;
      z = coords.$3;
    }
  }

  // Get formatted position string for display
  String getPositionString() {
    if (distance == null) return "Position: N/A";

    return "Dist: ${distance!.toStringAsFixed(2)}m\n"
        "Angle: ${horizontalAngle!.toStringAsFixed(1)}°\n"
        "3D: (${x!.toStringAsFixed(2)}, ${y!.toStringAsFixed(2)}, ${z!.toStringAsFixed(2)})";
  }

  // Check if 3D coordinates are available
  bool has3DCoordinates() {
    return distance != null && x != null && y != null && z != null;
  }
}

// Enhanced object tracker with 3D coordinate calculation
class SimpleTracker {
  List<TrackedObject> trackedObjects = [];
  int nextId = 1;
  static const double IOU_THRESHOLD = 0.3;
  static const int MAX_FRAMES_WITHOUT_UPDATE = 10;

  // Only track these specific classes
  static const Set<String> ALLOWED_CLASSES = {'apple', 'orange', 'banana'};

  double calculateIOU(Rect rect1, Rect rect2) {
    final intersection = rect1.intersect(rect2);
    if (intersection.isEmpty) return 0.0;

    final intersectionArea = intersection.width * intersection.height;
    final union = rect1.width * rect1.height +
        rect2.width * rect2.height -
        intersectionArea;

    return union > 0 ? intersectionArea / union : 0.0;
  }

  List<TrackedObject> update(
      List<dynamic> recognitions, double screenW, double screenH) {
    // Filter recognitions to only include allowed classes
    List<dynamic> filteredRecognitions = recognitions.where((rec) {
      String className = rec["detectedClass"].toString().toLowerCase();
      return ALLOWED_CLASSES.contains(className) &&
          CoordinateEstimationService.isDistanceSupported(className);
    }).toList();

    // Convert filtered recognitions to Rect objects
    List<Map<String, dynamic>> detections = filteredRecognitions.map((rec) {
      var x = rec["rect"]["x"] * screenW;
      var y = rec["rect"]["y"] * screenH;
      double w = rec["rect"]["w"] * screenW;
      double h = rec["rect"]["h"] * screenH;

      return {
        'rect': Rect.fromLTWH(x, y, w, h),
        'class': rec["detectedClass"].toString().toLowerCase(),
        'confidence': rec["confidenceInClass"],
      };
    }).toList();

    // Mark all tracked objects as not updated
    for (var obj in trackedObjects) {
      obj.framesSinceUpdate++;
    }

    // Match detections with existing tracks
    List<bool> detectionMatched = List.filled(detections.length, false);

    for (int i = 0; i < detections.length; i++) {
      if (detectionMatched[i]) continue;

      double bestIOU = 0;
      TrackedObject? bestMatch;

      for (var trackedObj in trackedObjects) {
        if (trackedObj.className == detections[i]['class']) {
          double iou = calculateIOU(trackedObj.rect, detections[i]['rect']);
          if (iou > bestIOU && iou > IOU_THRESHOLD) {
            bestIOU = iou;
            bestMatch = trackedObj;
          }
        }
      }

      if (bestMatch != null) {
        // Update existing track
        bestMatch.rect = detections[i]['rect'];
        bestMatch.confidence = detections[i]['confidence'];
        bestMatch.framesSinceUpdate = 0;
        bestMatch.history.add(bestMatch.rect);
        if (bestMatch.history.length > 5) {
          bestMatch.history.removeAt(0);
        }

        // Update screen dimensions and recalculate 3D coordinates
        bestMatch.screenWidth = screenW;
        bestMatch.screenHeight = screenH;
        bestMatch.calculate3DCoordinates();

        detectionMatched[i] = true;
      }
    }

    // Create new tracks for unmatched detections
    for (int i = 0; i < detections.length; i++) {
      if (!detectionMatched[i]) {
        TrackedObject newObj = TrackedObject(
          id: nextId++,
          className: detections[i]['class'],
          confidence: detections[i]['confidence'],
          rect: detections[i]['rect'],
          color: getColorForClass(detections[i]['class']),
          screenWidth: screenW,
          screenHeight: screenH,
        );

        // Calculate initial 3D coordinates
        newObj.calculate3DCoordinates();
        trackedObjects.add(newObj);
      }
    }

    // Remove tracks that haven't been updated for too long
    trackedObjects.removeWhere(
        (obj) => obj.framesSinceUpdate > MAX_FRAMES_WITHOUT_UPDATE);

    return trackedObjects;
  }

  // Get color based on object class
  Color getColorForClass(String className) {
    switch (className.toLowerCase()) {
      case 'banana':
        return Colors.yellow;
      case 'apple':
        return Colors.red;
      case 'orange':
        return Colors.orange;
      case 'bottle':
        return Colors.blue;
      case 'person':
        return Colors.green;
      case 'car':
        return Colors.purple;
      case 'cup':
        return Colors.cyan;
      case 'chair':
        return Colors.brown;
      case 'laptop':
        return Colors.grey;
      default:
        return Colors.white;
    }
  }
}

class RealTimeObjectDetection extends StatefulWidget {
  final List<CameraDescription> cameras;

  RealTimeObjectDetection({required this.cameras});

  @override
  _RealTimeObjectDetectionState createState() =>
      _RealTimeObjectDetectionState();
}

class _RealTimeObjectDetectionState extends State<RealTimeObjectDetection> {
  late CameraController _controller;
  bool isModelLoaded = false;
  bool isDetecting = false;
  List<dynamic>? recognitions;
  List<TrackedObject> trackedObjects = [];
  int imageHeight = 0;
  int imageWidth = 0;
  SimpleTracker tracker = SimpleTracker();
  bool show3DInfo = true; // Toggle for showing 3D information

  // Throttler to limit cloud update rate
  final throttler = Throttler(interval: const Duration(milliseconds: 250));

  @override
  void initState() {
    super.initState();
    loadModel();
    initializeCamera(null);
  }

  @override
  void dispose() {
    _controller.dispose();
    Tflite.close();
    super.dispose();
  }

  Future<void> loadModel() async {
    String? res = await Tflite.loadModel(
      model: 'assets/detect.tflite',
      labels: 'assets/labelmap.txt',
    );
    setState(() {
      isModelLoaded = res != null;
    });
  }

  void toggleCamera() {
    final lensDirection = _controller.description.lensDirection;
    CameraDescription newDescription;
    if (lensDirection == CameraLensDirection.front) {
      newDescription = widget.cameras.firstWhere((description) =>
          description.lensDirection == CameraLensDirection.back);
    } else {
      newDescription = widget.cameras.firstWhere((description) =>
          description.lensDirection == CameraLensDirection.front);
    }

    if (newDescription != null) {
      initializeCamera(newDescription);
    } else {
      print('Asked camera not available');
    }
  }

  void initializeCamera(description) async {
    if (description == null) {
      _controller = CameraController(
        widget.cameras[0],
        ResolutionPreset.high,
        enableAudio: false,
      );
    } else {
      _controller = CameraController(
        description,
        ResolutionPreset.high,
        enableAudio: false,
      );
    }

    await _controller.initialize();

    if (!mounted) {
      return;
    }
    _controller.startImageStream((CameraImage image) {
      if (isModelLoaded && !isDetecting) {
        runModel(image);
      }
    });
    setState(() {});
  }

  void runModel(CameraImage image) async {
    if (image.planes.isEmpty || isDetecting) return;

    setState(() {
      isDetecting = true;
    });

    try {
      var recognitions = await Tflite.detectObjectOnFrame(
        bytesList: image.planes.map((plane) => plane.bytes).toList(),
        model: 'SSDMobileNet',
        imageHeight: image.height,
        imageWidth: image.width,
        imageMean: 127.5,
        imageStd: 127.5,
        numResultsPerClass: 1,
        threshold: 0.4,
      );

      if (recognitions != null && mounted) {
        List<TrackedObject> updatedTracks = tracker.update(
            recognitions,
            MediaQuery.of(context).size.width,
            MediaQuery.of(context).size.height * 0.8);

        setState(() {
          this.recognitions = recognitions;
          this.trackedObjects = updatedTracks;
        });

        throttler.run(() {
          debugPrint("Uploading data to cloud...");
          // Your action here
          ObjectHandler.handleTrackedObjects(trackedObjects);
        });
      }
    } catch (e) {
      print('Error during inference: $e');
    } finally {
      if (mounted) {
        setState(() {
          isDetecting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return Container();
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('3D Object Tracking'),
        backgroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: Icon(show3DInfo ? Icons.visibility : Icons.visibility_off),
            onPressed: () {
              setState(() {
                show3DInfo = !show3DInfo;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height * 0.8,
            child: Stack(
              children: [
                CameraPreview(_controller),
                if (trackedObjects.isNotEmpty)
                  Enhanced3DBoundingBoxes(
                    trackedObjects: trackedObjects,
                    screenH: MediaQuery.of(context).size.height * 0.8,
                    screenW: MediaQuery.of(context).size.width,
                    show3DInfo: show3DInfo,
                  ),
                // Status overlay
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Objects: ${trackedObjects.length}\n3D Tracking: ${show3DInfo ? "ON" : "OFF"}',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: toggleCamera,
                icon: Icon(Icons.camera_front, size: 30),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    show3DInfo = !show3DInfo;
                  });
                },
                icon: Icon(
                    show3DInfo ? Icons.view_in_ar : Icons.view_in_ar_outlined,
                    size: 30),
              ),
            ],
          )
        ],
      ),
    );
  }
}

// Enhanced bounding boxes with 3D coordinate display
class Enhanced3DBoundingBoxes extends StatelessWidget {
  final List<TrackedObject> trackedObjects;
  final double screenH;
  final double screenW;
  final bool show3DInfo;

  Enhanced3DBoundingBoxes({
    required this.trackedObjects,
    required this.screenH,
    required this.screenW,
    required this.show3DInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: trackedObjects.map((obj) {
        return Positioned(
          left: obj.rect.left,
          top: obj.rect.top,
          width: obj.rect.width,
          height: obj.rect.height,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: obj.color,
                width: obj.has3DCoordinates() ? 3 : 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: obj.color.withOpacity(0.8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Basic info
                      Text(
                        "ID:${obj.id} ${obj.className} ${(obj.confidence * 100).toStringAsFixed(0)}%",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // 3D info if available and enabled
                      if (show3DInfo && obj.has3DCoordinates())
                        Text(
                          obj.getPositionString(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
