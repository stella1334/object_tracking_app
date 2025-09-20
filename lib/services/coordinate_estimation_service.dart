import 'dart:math' as math;

/// Service for estimating 3D coordinates and distances from camera feed
/// Provides distance estimation, angle calculation, and coordinate transformation
class CoordinateEstimationService {
  
  // ==================== CAMERA CONSTANTS ====================
  
  /// Default camera parameters (can be adjusted for specific devices)
  static const double cameraHFovDeg = 42.08; // Horizontal field of view
  static const double cameraFocalLengthMM = 4.0; // Focal length in millimeters
  static const double sensorWidthMM = 5.5385; // Sensor width in millimeters
  static const double defaultSensorHeightMm = 3.077; // Sensor height in millimeters
  
  /// Default image dimensions (adjust based on your camera resolution)
  static const double defaultImageWidthPx = 2296.0;
  static const double defaultImageHeightPx = 4080.0;
  
  // ==================== OBJECT HEIGHT DATABASE ====================
  
  /// Real-world object heights in meters for distance estimation
  /// Add more objects as needed for your specific use case
  static const Map<String, double> assumedRealHeightM = {
    // Fruits (commonly tracked objects)
    "banana": 0.19,
    "apple": 0.09,
    "orange": 0.075,
    
    // Common household items
    "bottle": 0.25,
    "cup": 0.1,
    "bowl": 0.08,
    "book": 0.02,
    "cell phone": 0.15,
    "laptop": 0.02,
    
    // Furniture
    "chair": 0.8,
    "couch": 0.85,
    "bed": 0.6,
    "toilet": 0.7,
    "tv": 0.6,
    
    // People and animals
    "person": 1.7,
    "cat": 0.25,
    "dog": 0.6,
    "bird": 0.15,
    
    // Vehicles
    "car": 1.5,
    "bicycle": 1.1,
    "motorcycle": 1.2,
    "bus": 3.0,
    "truck": 3.5,
    "airplane": 15.0,
    "boat": 5.0,
    
    // Large animals
    "horse": 1.6,
    "cow": 1.5,
    "elephant": 3.0,
    "bear": 0.9,
    "zebra": 1.4,
    "giraffe": 5.0,
    
    // Accessories
    "backpack": 0.5,
    "umbrella": 0.8,
    "handbag": 0.3,
    "suitcase": 0.7,
    "teddy bear": 0.3,
    
    // Decorative items
    "clock": 0.3,
    "vase": 0.25,
  };
  
  // ==================== DISTANCE ESTIMATION ====================
  
  /// Estimate distance using pinhole camera model
  /// 
  /// This is the core function for distance estimation based on object height
  /// in the image compared to known real-world height
  /// 
  /// [realHM] - Real height of object in meters (from database)
  /// [bboxHPx] - Bounding box height in pixels from detection
  /// [imgWPx] - Image width in pixels
  /// [fovHDeg] - Horizontal field of view in degrees (optional)
  /// [focLenMM] - Focal length in millimeters (optional)
  /// [sensorWidMM] - Sensor width in millimeters (optional)
  /// 
  /// Returns estimated distance in meters or null if calculation fails
  static double? estimateDistanceFromBbox(
    double? realHM,
    double bboxHPx,
    double imgWPx, {
    double fovHDeg = cameraHFovDeg,
    double focLenMM = cameraFocalLengthMM,
    double sensorWidMM = sensorWidthMM,
  }) {
    // Validation
    if (realHM == null || bboxHPx <= 0 || imgWPx <= 0) {
      return null;
    }
    
    try {
      // Calculate focal length in pixels using camera intrinsics
      final double pixelsPerMM = imgWPx / sensorWidMM;
      final double focLenPx = focLenMM * pixelsPerMM;

      // Apply pinhole camera model: distance = (real_height * focal_length_px) / height_px
      final double distM = (realHM * focLenPx) / bboxHPx;
      
      // Clamp distance to reasonable range (0.1m to 2000m)
      return math.max(0.1, math.min(2000.0, distM));
    } catch (e) {
      print('Error calculating distance: $e');
      return null;
    }
  }
  
  // ==================== ANGLE CALCULATION ====================
  
  /// Calculate simple horizontal angle from center of image (legacy method)
  /// 
  /// [centerX] - X coordinate of detection center
  /// [imgWidth] - Image width in pixels
  /// [fovHDeg] - Horizontal field of view in degrees
  /// 
  /// Returns angle in degrees (-fov/2 to +fov/2)
  static double calculateAngleFromCenter(
    double centerX,
    double imgWidth, {
    double fovHDeg = cameraHFovDeg,
  }) {
    if (imgWidth <= 0) return 0.0;
    
    // Calculate normalized position (-1 to +1)
    final double normalizedX = (centerX - (imgWidth / 2.0)) / (imgWidth / 2.0);
    
    // Convert to angle
    return normalizedX * (fovHDeg / 2.0);
  }
  
  /// Calculate comprehensive 3D angles using camera intrinsics
  /// 
  /// This is the preferred method for accurate angle calculation
  /// 
  /// [pixelX] - X coordinate of point in image (pixels)
  /// [pixelY] - Y coordinate of point in image (pixels)
  /// [focalLengthMm] - Camera focal length (millimeters)
  /// [sensorWidthMm] - Camera sensor width (millimeters)
  /// [sensorHeightMm] - Camera sensor height (millimeters)
  /// [imageWidthPx] - Image width in pixels
  /// [imageHeightPx] - Image height in pixels
  /// 
  /// Returns (horizontalAngleDeg, verticalAngleDeg, totalAngleDeg)
  static (double, double, double) calculateAngles(
    double pixelX,
    double pixelY, {
    double focalLengthMm = cameraFocalLengthMM,
    double sensorWidthMm = sensorWidthMM,
    double sensorHeightMm = defaultSensorHeightMm,
    double imageWidthPx = defaultImageWidthPx,
    double imageHeightPx = defaultImageHeightPx,
  }) {
    try {
      // Validate inputs
      if (imageWidthPx <= 0 || imageHeightPx <= 0 || 
          sensorWidthMm <= 0 || sensorHeightMm <= 0 || focalLengthMm <= 0) {
        return (0.0, 0.0, 0.0);
      }
      
      // Convert pixels per mm for both dimensions
      final double pixelsPerMmX = imageWidthPx / sensorWidthMm;
      final double pixelsPerMmY = imageHeightPx / sensorHeightMm;
      
      // Calculate image center
      final double centerX = imageWidthPx / 2;
      final double centerY = imageHeightPx / 2;
      
      // Calculate displacement from center in pixels
      final double deltaXPx = pixelX - centerX;
      final double deltaYPx = pixelY - centerY; // Y increases downward in images
      
      // Convert pixel displacement to physical displacement on sensor (mm)
      final double deltaXMm = deltaXPx / pixelsPerMmX;
      final double deltaYMm = deltaYPx / pixelsPerMmY;
      
      // Calculate angles using arctangent
      final double horizontalAngleRad = math.atan(deltaXMm / focalLengthMm);
      final double horizontalAngleDeg = horizontalAngleRad * 180.0 / math.pi;
      
      final double verticalAngleRad = math.atan(deltaYMm / focalLengthMm);
      final double verticalAngleDeg = verticalAngleRad * 180.0 / math.pi;
      
      // Total angular displacement from optical axis
      final double totalDisplacementMm = math.sqrt(deltaXMm * deltaXMm + deltaYMm * deltaYMm);
      final double totalAngleRad = math.atan(totalDisplacementMm / focalLengthMm);
      final double totalAngleDeg = totalAngleRad * 180.0 / math.pi;
      
      return (horizontalAngleDeg, verticalAngleDeg, totalAngleDeg);
    } catch (e) {
      print('Error calculating angles: $e');
      return (0.0, 0.0, 0.0);
    }
  }
  
  // ==================== COORDINATE TRANSFORMATION ====================
  
  /// Calculate 2D coordinates from distance and horizontal angle (legacy method)
  /// 
  /// [distance] - Distance in meters
  /// [angleDeg] - Horizontal angle in degrees
  /// 
  /// Returns (x, y) coordinates where y is forward and x is lateral
  static (double, double) calculateCoordinates(double distance, double angleDeg) {
    if (distance <= 0) return (0.0, 0.0);
    
    final double theta = math.pi * angleDeg / 180.0; // Convert to radians
    final double x = distance * math.sin(theta);
    final double y = distance * math.cos(theta);
    return (x, y);
  }
  
  /// Calculate 3D coordinates from distance and angles relative to the camera
  /// 
  /// This is the main method for converting detection data to 3D world coordinates
  /// 
  /// [distM] - Distance in meters (from distance estimation)
  /// [horizontalAngleDeg] - Horizontal angle in degrees (positive = right)
  /// [verticalAngleDeg] - Vertical angle in degrees (positive = down in image coords)
  /// 
  /// Returns (x, y, z) coordinates where:
  /// - x: lateral position (positive = right of camera)
  /// - y: forward distance (positive = away from camera)
  /// - z: vertical position (positive = above camera level, negative = below)
  static (double, double, double) calculateCoordinates3D(
    double distM,
    double horizontalAngleDeg,
    double verticalAngleDeg,
  ) {
    if (distM <= 0) return (0.0, 0.0, 0.0);
    
    try {
      // Convert angles to radians for trigonometric calculations
      final double hRad = horizontalAngleDeg * math.pi / 180.0;
      final double vRad = verticalAngleDeg * math.pi / 180.0;

      // Calculate 3D coordinates using spherical to cartesian conversion
      // Forward distance projection (y-axis) - always positive away from camera
      final double y = distM * math.cos(hRad) * math.cos(vRad);
      
      // Lateral position (x-axis) - positive = right, negative = left
      final double x = distM * math.sin(hRad) * math.cos(vRad);
      
      // Vertical position (z-axis) - positive = up, negative = down
      // Negate because positive vertical angle in image means looking down
      final double z = -distM * math.sin(vRad);

      return (x, y, z);
    } catch (e) {
      print('Error calculating 3D coordinates: $e');
      return (0.0, 0.0, 0.0);
    }
  }
  
  // ==================== UTILITY METHODS ====================
  
  /// Get assumed real height for a given class name
  /// 
  /// [className] - Name of the detected object class
  /// 
  /// Returns assumed height in meters or null if not found
  static double? getAssumedHeight(String className) {
    return assumedRealHeightM[className.toLowerCase()];
  }

  /// Check if distance estimation is supported for a class
  /// 
  /// [className] - Name of the detected object class
  /// 
  /// Returns true if distance estimation is supported
  static bool isDistanceSupported(String className) {
    return assumedRealHeightM.containsKey(className.toLowerCase());
  }
  
  /// Get list of all supported object classes
  /// 
  /// Returns list of class names that support distance estimation
  static List<String> getSupportedClasses() {
    return assumedRealHeightM.keys.toList();
  }
  
  /// Add or update height for a custom object class
  /// 
  /// [className] - Name of the object class
  /// [heightM] - Real-world height in meters
  /// 
  /// Note: This modifies the runtime database, not the constant
  static void addCustomObjectHeight(String className, double heightM) {
    if (heightM > 0) {
      // Since the original is const, we'd need a separate mutable map
      // For now, this is a placeholder for potential future enhancement
      print('Custom height for $className: ${heightM}m (feature not yet implemented)');
    }
  }
  
  /// Calculate the estimated accuracy of distance measurement
  /// 
  /// [distance] - Estimated distance in meters
  /// [bboxHeight] - Bounding box height in pixels
  /// 
  /// Returns estimated accuracy as a percentage (0-100)
  static double estimateAccuracy(double distance, double bboxHeight) {
    // Accuracy decreases with distance and smaller bounding boxes
    // This is a simplified model - in practice, accuracy depends on many factors
    
    if (distance <= 0 || bboxHeight <= 0) return 0.0;
    
    // Base accuracy starts high for close objects with large bounding boxes
    double baseAccuracy = 95.0;
    
    // Reduce accuracy based on distance (exponential decay)
    double distanceFactor = math.exp(-distance / 10.0);
    
    // Reduce accuracy for smaller bounding boxes
    double sizeFactor = math.min(1.0, bboxHeight / 100.0);
    
    double accuracy = baseAccuracy * distanceFactor * sizeFactor;
    
    return math.max(10.0, math.min(95.0, accuracy)); // Clamp between 10-95%
  }
  
  /// Convert 3D coordinates to polar coordinates (distance, azimuth, elevation)
  /// 
  /// [x] - Lateral position
  /// [y] - Forward distance
  /// [z] - Vertical position
  /// 
  /// Returns (distance, azimuth_deg, elevation_deg)
  static (double, double, double) cartesianToPolar(double x, double y, double z) {
    try {
      final double distance = math.sqrt(x * x + y * y + z * z);
      final double azimuth = math.atan2(x, y) * 180.0 / math.pi;
      final double elevation = math.asin(z / distance) * 180.0 / math.pi;
      
      return (distance, azimuth, elevation);
    } catch (e) {
      print('Error converting to polar coordinates: $e');
      return (0.0, 0.0, 0.0);
    }
  }
  
  /// Calculate relative velocity between two 3D positions
  /// 
  /// [x1, y1, z1] - Previous position
  /// [x2, y2, z2] - Current position
  /// [deltaTime] - Time difference in seconds
  /// 
  /// Returns (velocity_x, velocity_y, velocity_z) in m/s
  static (double, double, double) calculateVelocity3D(
    double x1, double y1, double z1,
    double x2, double y2, double z2,
    double deltaTime,
  ) {
    if (deltaTime <= 0) return (0.0, 0.0, 0.0);
    
    final double vx = (x2 - x1) / deltaTime;
    final double vy = (y2 - y1) / deltaTime;
    final double vz = (z2 - z1) / deltaTime;
    
    return (vx, vy, vz);
  }
  
  /// Format 3D coordinates for display
  /// 
  /// [x] - Lateral position
  /// [y] - Forward distance  
  /// [z] - Vertical position
  /// [precision] - Number of decimal places
  /// 
  /// Returns formatted string
  static String formatCoordinates(double x, double y, double z, {int precision = 2}) {
    return '(${x.toStringAsFixed(precision)}, ${y.toStringAsFixed(precision)}, ${z.toStringAsFixed(precision)})';
  }
  
  /// Format distance with appropriate units
  /// 
  /// [distance] - Distance in meters
  /// 
  /// Returns formatted string with appropriate units
  static String formatDistance(double distance) {
    if (distance < 1.0) {
      return '${(distance * 100).toStringAsFixed(0)}cm';
    } else if (distance < 1000.0) {
      return '${distance.toStringAsFixed(2)}m';
    } else {
      return '${(distance / 1000.0).toStringAsFixed(2)}km';
    }
  }
  
  // ==================== VALIDATION METHODS ====================
  
  /// Validate if calculated coordinates are reasonable
  /// 
  /// [x, y, z] - 3D coordinates
  /// [maxDistance] - Maximum reasonable distance in meters
  /// 
  /// Returns true if coordinates seem reasonable
  static bool validateCoordinates(double x, double y, double z, {double maxDistance = 1000.0}) {
    final double distance = math.sqrt(x * x + y * y + z * z);
    
    // Check if distance is within reasonable bounds
    if (distance < 0.05 || distance > maxDistance) return false;
    
    // Check for NaN or infinite values
    if (!distance.isFinite || !x.isFinite || !y.isFinite || !z.isFinite) return false;
    
    // Forward distance should generally be positive (object in front of camera)
    if (y < 0) return false;
    
    return true;
  }
  
  /// Check if detection bounding box is suitable for distance estimation
  /// 
  /// [bboxWidth] - Bounding box width in pixels
  /// [bboxHeight] - Bounding box height in pixels
  /// [minSize] - Minimum size threshold
  /// [maxSize] - Maximum size threshold (relative to image)
  /// 
  /// Returns true if bounding box is suitable for distance estimation
  static bool validateBoundingBox(
    double bboxWidth, 
    double bboxHeight, {
    double minSize = 10.0,
    double maxSize = 0.8, // 80% of image
  }) {
    // Check minimum size
    if (bboxWidth < minSize || bboxHeight < minSize) return false;
    
    // Check aspect ratio (should be reasonable)
    final double aspectRatio = bboxWidth / bboxHeight;
    if (aspectRatio > 5.0 || aspectRatio < 0.2) return false;
    
    return true;
  }
  
  // ==================== DEBUG AND TESTING ====================
  
  /// Print detailed information about a coordinate calculation
  /// 
  /// Useful for debugging and understanding the calculation process
  static void debugCoordinateCalculation(
    String className,
    double bboxHeight,
    double centerX,
    double centerY,
    double imageWidth,
    double imageHeight,
  ) {
    print('\n=== Coordinate Calculation Debug ===');
    print('Object: $className');
    print('Bounding box height: ${bboxHeight.toStringAsFixed(2)}px');
    print('Center position: (${centerX.toStringAsFixed(2)}, ${centerY.toStringAsFixed(2)})');
    print('Image dimensions: ${imageWidth.toStringAsFixed(0)}x${imageHeight.toStringAsFixed(0)}');
    
    final double? realHeight = getAssumedHeight(className);
    print('Assumed real height: ${realHeight?.toStringAsFixed(3) ?? "Unknown"}m');
    
    if (realHeight != null) {
      final double? distance = estimateDistanceFromBbox(realHeight, bboxHeight, imageWidth);
      print('Estimated distance: ${distance?.toStringAsFixed(2) ?? "Error"}m');
      
      if (distance != null) {
        final angles = calculateAngles(centerX, centerY, 
          imageWidthPx: imageWidth, imageHeightPx: imageHeight);
        print('Angles: H=${angles.$1.toStringAsFixed(2)}°, V=${angles.$2.toStringAsFixed(2)}°');
        
        final coords = calculateCoordinates3D(distance, angles.$1, angles.$2);
        print('3D Coordinates: ${formatCoordinates(coords.$1, coords.$2, coords.$3)}');
        
        final accuracy = estimateAccuracy(distance, bboxHeight);
        print('Estimated accuracy: ${accuracy.toStringAsFixed(1)}%');
      }
    }
    print('=====================================\n');
  }
  
  /// Test the coordinate estimation system with sample data
  /// 
  /// Useful for validating the implementation
  static void runSystemTest() {
    print('\n=== Coordinate Estimation System Test ===');
    
    final testCases = [
      {'class': 'apple', 'height': 50.0, 'x': 1148.0, 'y': 1000.0},
      {'class': 'banana', 'height': 80.0, 'x': 800.0, 'y': 1200.0},
      {'class': 'person', 'height': 200.0, 'x': 1500.0, 'y': 800.0},
    ];
    
    for (var testCase in testCases) {
      debugCoordinateCalculation(
        testCase['class'] as String,
        testCase['height'] as double,
        testCase['x'] as double,
        testCase['y'] as double,
        defaultImageWidthPx,
        defaultImageHeightPx,
      );
    }
    
    print('=== Test Complete ===\n');
  }
}