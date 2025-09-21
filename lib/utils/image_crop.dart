import 'dart:typed_data';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ImageCrop {
  /// Convert the YUV420 frame to RGB, crop given image-space rect, JPEG encode,
  /// and upload to Firebase Storage.
  /// [imageRectImageSpace] must be in camera image pixel coordinates (0..width/height).
  Future<String> cropAndUploadFromYuvFrame({
    required CameraImage frame,
    required Rect imageRectImageSpace,
    required String objectClass,
    required int objectId,
    int jpegQuality = 90,
  }) async {
    // Clamp crop rect to the image bounds (defensive)
    final int iw = frame.width;
    final int ih = frame.height;
    final Rect bounds = Rect.fromLTWH(0, 0, iw.toDouble(), ih.toDouble());
    final Rect safe = imageRectImageSpace.intersect(bounds);

    if (safe.isEmpty) {
      throw StateError('Crop rect is empty after clamping.');
    }

    // 1) YUV420 → RGB image (fast, allocation-aware)
    final img.Image rgb = _yuv420toRgbImage(frame);

    // 2) Crop in image-space (integers)
    final int cx = safe.left.floor();
    final int cy = safe.top.floor();
    final int cw = math.max(1, safe.width.floor());
    final int ch = math.max(1, safe.height.floor());

    final img.Image cropped =
        img.copyCrop(rgb, x: cx, y: cy, width: cw, height: ch);

    // 3) Encode JPEG
    final Uint8List jpeg =
        Uint8List.fromList(img.encodeJpg(cropped, quality: jpegQuality));

    // 4) Upload to Firebase Storage
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = 'detections/$objectClass/${ts}_${objectId}.jpg';
    final ref = FirebaseStorage.instance.ref().child(path);

    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
      customMetadata: {
        'class': objectClass,
        'object_id': objectId.toString(),
        'w': cw.toString(),
        'h': ch.toString(),
        'source_w': iw.toString(),
        'source_h': ih.toString(),
        'ts': ts.toString(),
      },
    );

    await ref.putData(jpeg, metadata);
    return await ref.getDownloadURL();
  }

  /// Converts a YUV420 (NV21/Android) CameraImage to an RGB image (package:image).
  img.Image _yuv420toRgbImage(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    final Plane planeY = image.planes[0];
    final Plane planeU = image.planes[1];
    final Plane planeV = image.planes[2];

    final int strideY = planeY.bytesPerRow;
    final int strideU = planeU.bytesPerRow;
    final int strideV = planeV.bytesPerRow;
    final int pixStrideU = planeU.bytesPerPixel ?? 1; // usually 2
    final int pixStrideV = planeV.bytesPerPixel ?? 1;

    final Uint8List bytesY = planeY.bytes;
    final Uint8List bytesU = planeU.bytes;
    final Uint8List bytesV = planeV.bytes;

    final img.Image out = img.Image(width: width, height: height);

    // YUV420p with interleaved UV at half resolution; convert per pixel.
    for (int y = 0; y < height; y++) {
      final int uvRow = (y >> 1);
      final int yRow = y * strideY;

      for (int x = 0; x < width; x++) {
        final int uvCol = (x >> 1);

        final int yIndex = yRow + x;
        final int uIndex = uvRow * strideU + uvCol * pixStrideU;
        final int vIndex = uvRow * strideV + uvCol * pixStrideV;

        final int Y = bytesY[yIndex];
        final int U = bytesU[uIndex];
        final int V = bytesV[vIndex];

        // YUV -> RGB (BT.601)
        double yf = Y.toDouble();
        double uf = U.toDouble() - 128.0;
        double vf = V.toDouble() - 128.0;

        int r = (yf + 1.402 * vf).round();
        int g = (yf - 0.344136 * uf - 0.714136 * vf).round();
        int b = (yf + 1.772 * uf).round();

        // Clamp 0..255
        if (r < 0)
          r = 0;
        else if (r > 255) r = 255;
        if (g < 0)
          g = 0;
        else if (g > 255) g = 255;
        if (b < 0)
          b = 0;
        else if (b > 255) b = 255;

        out.setPixelRgb(x, y, r, g, b);
      }
    }

    return out;
  }

  /// Convert a screen-space rect back to image-space rect
  Rect screenRectToImageRect({
    required Rect screenRect,
    required double screenW,
    required double screenH,
    required int imageW,
    required int imageH,
  }) {
    final double xNorm = screenRect.left / screenW;
    final double yNorm = screenRect.top / screenH;
    final double wNorm = screenRect.width / screenW;
    final double hNorm = screenRect.height / screenH;

    return Rect.fromLTWH(
      xNorm * imageW,
      yNorm * imageH,
      wNorm * imageW,
      hNorm * imageH,
    );
  }
}
