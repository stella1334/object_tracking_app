// lib/core/services/fruit_point_repository.dart
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as storage;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:realtime_obj_detection/services/cloud_services/fruit_point.dart';

class FruitPointRepository {
  final FirebaseFirestore _db;
  final storage.FirebaseStorage _storage;

  FruitPointRepository({
    FirebaseFirestore? db,
    storage.FirebaseStorage? storageInstance,
  })  : _db = db ?? FirebaseFirestore.instance,
        _storage = storageInstance ?? storage.FirebaseStorage.instance;

  /// Upsert FruitPoint into `points/{id}`.
  /// If the document exists, its lat/lon arrays are appended to `point.path` before saving.
  /// Additionally, if the local path is empty and image bytes are provided, upload the image and set imageUrl.
  Future<void> upsertAndAppendPath(
    FruitPoint point, {
    Uint8List? imageBytes,
    String? contentType, // e.g. 'image/jpeg' or 'image/png'
    String? fileName, // optional override; default is generated
  }) async {
    // 1) Optional image upload (ONLY if local path is empty and no imageUrl yet)
    if (point.path.isEmpty &&
        imageBytes != null &&
        (point.imageUrl == null || point.imageUrl!.isEmpty)) {
      final url = await _uploadPointImage(
        pointId: point.id,
        bytes: imageBytes,
        contentType: contentType,
        fileName: fileName,
        metadata: {
          'pointId': point.id,
          'name': point.name,
          'timestamp': point.tracked.toIso8601String(),
        },
      );
      // update point with the uploaded URL
      point = point.copyWith(imageUrl: url);
    }

    // 2) Firestore transaction to merge/append path safely
    final docRef = _db.collection('points').doc(point.id);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);

      // Start with the local path
      final List<LatLng> mergedPath = List<LatLng>.from(point.path);

      if (snap.exists) {
        final data = snap.data();
        if (data != null) {
          final existingLat = _readDoubleList(data['lat']);
          final existingLon = _readDoubleList(data['lon']);
          if (existingLat.isNotEmpty && existingLon.isNotEmpty) {
            final n = existingLat.length < existingLon.length
                ? existingLat.length
                : existingLon.length;
            for (var i = 0; i < n; i++) {
              final lat = existingLat[i].clamp(-90.0, 90.0);
              final lon = existingLon[i].clamp(-180.0, 180.0);
              mergedPath.add(LatLng(lat, lon));
            }
          }
        }
      }

      final updated = point.copyWith(path: mergedPath);

      // Write back; merge to preserve any future/unknown fields
      tx.set(docRef, updated.toMap(), SetOptions(merge: true));
    });
  }

  // ---------- Storage helper ----------

  Future<String> _uploadPointImage({
    required String pointId,
    required Uint8List bytes,
    Map<String, String>? metadata,
    String? contentType,
    String? fileName,
  }) async {
    final safeFileName =
        fileName ?? 'img_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final ref =
        _storage.ref().child('points').child(pointId).child(safeFileName);

    final meta = storage.SettableMetadata(
      contentType: contentType ?? 'image/jpeg',
      customMetadata: metadata,
    );

    final task = await ref.putData(bytes, meta);
    return await task.ref.getDownloadURL();
  }

  // ---------- helpers ----------

  List<double> _readDoubleList(dynamic v) {
    if (v == null) return const [];
    if (v is List) {
      return v
          .where((e) => e != null)
          .map<double>((e) => e is int ? e.toDouble() : (e as num).toDouble())
          .toList(growable: false);
    }
    return const [];
  }
}
