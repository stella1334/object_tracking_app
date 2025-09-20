import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:realtime_obj_detection/location_service.dart';
import 'package:realtime_obj_detection/main.dart';
import 'package:realtime_obj_detection/services/cloud_services/cloud_interface.dart';
import 'package:realtime_obj_detection/services/cloud_services/fruit_point.dart';

class ObjectHandler {
  static Future<void> handleTrackedObjects(
      List<TrackedObject> trackedObjects) async {
    // Process the list of tracked objects
    for (var obj in trackedObjects) {
      // Convert TrackedObject to FruitPoint and upload to Firestore
      debugPrint('Handling object: ${obj.className} at ${obj.rect}');

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

      // Create a LatLng list with only realWorldPosition in it
      List<LatLng> cu = [
        LatLng(realWorldPosition.latitude, realWorldPosition.longitude)
      ];

      final repo = FruitPointRepository();
      await repo.upsertAndAppendPath(FruitPoint(
          id: '${obj.id} ${obj.className}',
          name: obj.className,
          icon: obj.className,
          path: cu,
          altitude: realWorldPosition.altitude.toInt(),
          tracked: DateTime.now()));
    }
  }
}
