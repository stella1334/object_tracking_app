import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:realtime_obj_detection/location_service.dart';
import 'package:realtime_obj_detection/main.dart';
import 'package:realtime_obj_detection/services/cloud_services/cloud_interface.dart';
import 'package:realtime_obj_detection/services/cloud_services/fruit_point.dart';
import 'package:realtime_obj_detection/utils/image_crop.dart';

class ObjectHandler {
  // Random number between 0 and 1000 to differentiate object IDs in demo
  static int randomId = DateTime.now().millisecondsSinceEpoch % 10000;

  static Future<void> handleTrackedObjects(
      List<TrackedObject> trackedObjects,
      {CameraImage? cameraImage,
      double? screenWidth,
      double? screenHeight}) async {
    // Process the list of tracked objects
    for (var obj in trackedObjects) {
      // Convert TrackedObject to FruitPoint and upload to Firestore
      debugPrint('Handling object: ${obj.className} at ${obj.rect}');

      // Crop and upload image if camera frame is available
      String? imageUrl;
      if (cameraImage != null && screenWidth != null && screenHeight != null) {
        try {
          final imageCrop = ImageCrop();
          
          // Convert screen rect to image rect
          final imageRect = imageCrop.screenRectToImageRect(
            screenRect: obj.rect,
            screenW: screenWidth,
            screenH: screenHeight,
            imageW: cameraImage.width,
            imageH: cameraImage.height,
          );

          // Crop and upload the image
          imageUrl = await imageCrop.cropAndUploadFromYuvFrame(
            frame: cameraImage,
            imageRectImageSpace: imageRect,
            objectClass: obj.className,
            objectId: obj.id,
            jpegQuality: 85,
          );
          
          debugPrint('Uploaded cropped image for ${obj.className}: $imageUrl');
        } catch (e) {
          debugPrint('Failed to crop and upload image for ${obj.className}: $e');
        }
      }

      Position currentPosition = await LocationService.determinePosition();
      debugPrint(
          'Current position: ${currentPosition.latitude}, ${currentPosition.longitude}');

      // Calculate real world position based on object location in the frame
      // TODO: for demo purposes x and y are multiplied by 100
      Position realWorldPosition = LocationService.calculateResultingPosition(
        currentPosition,
        obj.x != null ? obj.x! * 100 : 0,
        obj.y != null ? obj.y! * 100 : 0,
        obj.z != null ? obj.z! * 100 : 0,
      );

      debugPrint(
          'Real world position: ${realWorldPosition.latitude}, ${realWorldPosition.longitude}');

      // Convert the on-screen rect back to image-space

      // Create a LatLng list with only realWorldPosition in it
      List<LatLng> cu = [
        LatLng(realWorldPosition.latitude, realWorldPosition.longitude)
      ];

      final repo = FruitPointRepository();
      await repo.upsertAndAppendPath(
          FruitPoint(
              id: '$randomId ${obj.id} ${obj.className}',
              name: obj.className,
              icon: obj.className,
              path: cu,
              altitude: realWorldPosition.altitude.toInt(),
              tracked: DateTime.now(),
              imageUrl: imageUrl), // Use the uploaded image URL
          imageBytes: null // Image already uploaded above
          );
    }
  }
}
