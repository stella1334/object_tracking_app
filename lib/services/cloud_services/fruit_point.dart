import 'package:google_maps_flutter/google_maps_flutter.dart';
// If you use Firestore, keep this import to read/write Timestamp.
// If not using Firestore here, you can remove it and the code will still compile,
// but toMap() will then store ISO-8601 strings instead of a Firestore Timestamp.
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

/// Firestore schema (updated)
/// {
///   "id": "001",
///   "name": "Banana 002",
///   "icon": "banana",                 // one of: banana|apple|orange
///   "lat": [47.420295, 47.42029, ...],// array double
///   "lon": [9.37004, 9.37003, ...],   // array double
///   "altitude": 78,                   // REQUIRED (number)
///   "object_image_link": "https://...", // optional (string)
///   "detected_text": "ripe banana",     // optional (string)
///   "tracked": Firestore Timestamp or ms since epoch or ISO string // REQUIRED
/// }
class FruitPoint {
  final String id;
  final String name;
  final String icon;

  /// Path represented as zipped lat/lon arrays.
  final List<LatLng> path;

  /// Convenience: first coordinate as "anchor" position.
  LatLng get position => path.first;

  /// Required altitude.
  final int altitude;

  /// Optional image link.
  final String? imageUrl;

  /// Optional detected text (e.g., OCR result).
  final String? detectedText;

  /// Required timestamp of the detection/record (UTC recommended).
  final DateTime tracked;

  FruitPoint({
    required this.id,
    required this.name,
    required this.icon,
    required this.path,
    required this.altitude,
    required this.tracked,
    this.imageUrl,
    this.detectedText,
  }) : assert(path.isNotEmpty, 'path must contain at least one coordinate');

  // ---- helpers ----
  static double _asDouble(dynamic v) =>
      v is int ? v.toDouble() : (v as num).toDouble();
  static int _asInt(dynamic v) => v is double ? v.round() : (v as num).toInt();

  static List<double> _readDoubleList(dynamic v) {
    if (v == null) return const [];
    if (v is List) {
      return v
          .where((e) => e != null)
          .map<double>((e) => _asDouble(e))
          .toList(growable: false);
    }
    return const [];
  }

  /// Robust timestamp parser:
  /// - Firestore Timestamp
  /// - { _seconds, _nanoseconds } (export)
  /// - { seconds, nanoseconds } (alt)
  /// - int/double epoch (ms or s)
  /// - ISO-8601 string
  static DateTime _parseTimestamp(dynamic v) {
    if (v == null) {
      throw ArgumentError('Missing required field: tracked');
    }

    // Firestore Timestamp
    if (v is Timestamp) {
      return v.toDate();
    }

    // Firestore export shapes
    if (v is Map) {
      if (v.containsKey('_seconds')) {
        final sec = (v['_seconds'] as num).toInt();
        final nsec = (v['_nanoseconds'] as num? ?? 0).toInt();
        return DateTime.fromMillisecondsSinceEpoch(sec * 1000 + nsec ~/ 1e6);
      }
      if (v.containsKey('seconds')) {
        final sec = (v['seconds'] as num).toInt();
        final nsec = (v['nanoseconds'] as num? ?? 0).toInt();
        return DateTime.fromMillisecondsSinceEpoch(sec * 1000 + nsec ~/ 1e6);
      }
    }

    // Numeric epoch
    if (v is num) {
      final n = v.toDouble();
      // Heuristic: >= 1e12 looks like ms, else seconds
      final ms = n >= 1e12 ? n.toInt() : (n * 1000).toInt();
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    }

    // String ISO-8601
    if (v is String) {
      final dt = DateTime.tryParse(v);
      if (dt != null) return dt.toUtc();
    }

    throw ArgumentError('Unsupported timestamp format: $v');
  }

  /// Create FruitPoint from Firestore document data.
  factory FruitPoint.fromMap(Map<String, dynamic> m) {
    // --- icon validation ---
    final icon = (m['icon'] as String?)?.toLowerCase().trim();
    const allowed = {'banana', 'apple', 'orange'};
    if (icon == null || !allowed.contains(icon)) {
      throw ArgumentError(
        'Invalid or missing icon: $icon. Allowed: ${allowed.join(', ')}',
      );
    }

    // --- id/name ---
    final id = (m['id'] ?? m['docId']) as String;
    final name = (m['name'] as String?) ?? id;

    // --- coords ---
    final List<double> latList = _readDoubleList(m['lat']);
    final List<double> lonList = _readDoubleList(m['lon']);

    List<LatLng> path = [];
    if (latList.isNotEmpty && lonList.isNotEmpty) {
      final int n = latList.length < lonList.length
          ? latList.length
          : lonList.length;
      path = List<LatLng>.generate(
        n,
        (i) => LatLng(
          latList[i].clamp(-90.0, 90.0),
          lonList[i].clamp(-180.0, 180.0),
        ),
        growable: false,
      );
    }

    if (path.isEmpty) {
      throw ArgumentError(
        'No coordinates found: requires lat[] & lon[] or single lat/lon.',
      );
    }

    // --- required altitude ---
    final altitudeRaw = m['altitude'];
    if (altitudeRaw == null) {
      throw ArgumentError('Missing required field: altitude');
    }
    final int altitude = _asInt(altitudeRaw);

    // --- required timestamp ---
    final DateTime tracked = _parseTimestamp(m['tracked']);

    // --- optionals ---
    final String? imageUrl = (m['object_image_link'] as String?)?.trim();
    final String? detectedText = (m['detected_text'] as String?)?.trim();

    return FruitPoint(
      id: id,
      name: name,
      icon: icon,
      path: path,
      altitude: altitude,
      tracked: tracked,
      imageUrl: (imageUrl?.isEmpty ?? true) ? null : imageUrl,
      detectedText: (detectedText?.isEmpty ?? true) ? null : detectedText,
    );
  }

  /// Map back to Firestore (new schema).
  Map<String, dynamic> toMap() {
    final lats = path.map((p) => p.latitude).toList(growable: false);
    final lons = path.map((p) => p.longitude).toList(growable: false);

    // Prefer Firestore Timestamp if the import exists, else ISO string.
    final dynamic trackedTsForFirestore = Timestamp.fromDate(tracked.toUtc());

    return <String, dynamic>{
      'id': id,
      'name': name,
      'icon': icon,
      'lat': lats,
      'lon': lons,
      'altitude': altitude,
      'tracked': trackedTsForFirestore,
      if (imageUrl != null) 'object_image_link': imageUrl,
      if (detectedText != null) 'detected_text': detectedText,
    };
  }

  FruitPoint copyWith({
    String? id,
    String? name,
    String? icon,
    List<LatLng>? path,
    int? altitude,
    String? imageUrl,
    String? detectedText,
    DateTime? tracked,
  }) {
    return FruitPoint(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      path: path ?? this.path,
      altitude: altitude ?? this.altitude,
      tracked: tracked ?? this.tracked,
      imageUrl: imageUrl ?? this.imageUrl,
      detectedText: detectedText ?? this.detectedText,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is FruitPoint && other.id == id);

  @override
  int get hashCode => id.hashCode;

  /// Create FruitPoint from JSON with validation and clamping
  factory FruitPoint.fromJson(Map<String, dynamic> json) {
    // --- icon ---
    final rawIcon = (json['icon'] as String?)?.toLowerCase().trim();
    const allowed = {'banana', 'apple', 'orange'};
    if (rawIcon == null || !allowed.contains(rawIcon)) {
      throw ArgumentError(
        'Invalid or missing icon: $rawIcon. Allowed: ${allowed.join(', ')}',
      );
    }

    // --- id & name ---
    final id = (json['id'] ?? json['docId']) as String;
    final name = (json['name'] as String?) ?? id;

    // --- required altitude ---
    final altitudeRaw = json['altitude'];
    if (altitudeRaw == null) {
      throw ArgumentError('Missing required field: altitude');
    }
    final int altitude = altitudeRaw is double
        ? altitudeRaw.round()
        : (altitudeRaw as num).toInt();

    // --- lat/lon arrays (with clamping) ---
    List<dynamic>? latRaw = json['lat'] as List<dynamic>?;
    List<dynamic>? lonRaw = json['lon'] as List<dynamic>?;

    List<LatLng> path = [];
    if (latRaw != null &&
        lonRaw != null &&
        latRaw.isNotEmpty &&
        lonRaw.isNotEmpty) {
      final n = latRaw.length < lonRaw.length ? latRaw.length : lonRaw.length;
      for (var i = 0; i < n; i++) {
        double lat = (latRaw[i] as num).toDouble();
        double lon = (lonRaw[i] as num).toDouble();
        if (lat < -90.0 || lat > 90.0) lat = lat.clamp(-90.0, 90.0);
        if (lon < -180.0 || lon > 180.0) lon = lon.clamp(-180.0, 180.0);
        path.add(LatLng(lat, lon));
      }
    } else {
      // Legacy single lat/lon
      final lat = (json['lat'] as num).toDouble().clamp(-90.0, 90.0);
      final lon = (json['lon'] as num).toDouble().clamp(-180.0, 180.0);
      path = [LatLng(lat, lon)];
    }

    if (path.isEmpty) {
      throw ArgumentError('FruitPoint requires at least one coordinate.');
    }

    // --- required timestamp ---
    final DateTime tracked = _parseTimestamp(json['timestamp']);

    // --- optionals ---
    final imageUrl = (json['object_image_link'] as String?)?.trim();
    final detectedText = (json['detected_text'] as String?)?.trim();

    return FruitPoint(
      id: id,
      name: name,
      icon: rawIcon,
      path: path,
      altitude: altitude,
      tracked: tracked,
      imageUrl: (imageUrl?.isEmpty ?? true) ? null : imageUrl,
      detectedText: (detectedText?.isEmpty ?? true) ? null : detectedText,
    );
  }

  /// Convert to LatLng for Google Maps
  LatLng toLatLng() => LatLng(path.first.latitude, path.first.longitude);

  /// Returns the path as a list of LatLng coordinates for Google Maps.
  /// Returns an unmodifiable copy to prevent external mutation.
  List<LatLng> pathAsLatLng() {
    return List<LatLng>.unmodifiable(path);
  }

  @override
  String toString() {
    return 'FruitPoint(id: $id, name: $name, icon: $icon, '
        'pathLen: ${path.length}, altitude: $altitude, '
        'tracked: ${tracked.toIso8601String()}, '
        'detectedText: ${detectedText ?? "-"}'
        ')';
  }
}
