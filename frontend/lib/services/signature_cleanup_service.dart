import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class CleanedSignatureResult {
  final Uint8List cleanedBytes;
  final bool success;
  final String? errorMessage;

  CleanedSignatureResult({
    required this.cleanedBytes,
    required this.success,
    this.errorMessage,
  });
}

class CleanupParams {
  final Uint8List originalBytes;
  const CleanupParams(this.originalBytes);
}

class SignatureCleanupService {
  
  // Background processing isolate wrapper
  static Future<CleanedSignatureResult> cleanSignature(Uint8List originalBytes) async {
    try {
      final result = await compute(_processSignatureInBackground, CleanupParams(originalBytes));
      return result;
    } catch (e) {
      return CleanedSignatureResult(
        cleanedBytes: originalBytes,
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  // Process signature image offline inside background isolate
  static CleanedSignatureResult _processSignatureInBackground(CleanupParams params) {
    try {
      final original = img.decodeImage(params.originalBytes);
      if (original == null) {
        return CleanedSignatureResult(
          cleanedBytes: params.originalBytes,
          success: false,
          errorMessage: 'Unable to decode original image format.',
        );
      }

      // 1. Resize if image is too large to speed up processing and prevent OOM
      img.Image processed = original;
      const maxDim = 1000;
      if (original.width > maxDim || original.height > maxDim) {
        if (original.width > original.height) {
          processed = img.copyResize(original, width: maxDim);
        } else {
          processed = img.copyResize(original, height: maxDim);
        }
      }

      // 2. Background color & luminance analysis
      // Sample border pixels (first/last 10 rows and columns) to calculate background threshold
      int totalLuminance = 0;
      int borderCount = 0;
      final w = processed.width;
      final h = processed.height;

      // Top and bottom borders
      for (int x = 0; x < w; x++) {
        for (int y = 0; y < 10 && y < h; y++) {
          final pixel = processed.getPixel(x, y);
          totalLuminance += img.getLuminance(pixel).toInt();
          borderCount++;
        }
        for (int y = h - 1; y > h - 11 && y >= 0; y--) {
          final pixel = processed.getPixel(x, y);
          totalLuminance += img.getLuminance(pixel).toInt();
          borderCount++;
        }
      }

      // Left and right borders
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < 10 && x < w; x++) {
          final pixel = processed.getPixel(x, y);
          totalLuminance += img.getLuminance(pixel).toInt();
          borderCount++;
        }
        for (int x = w - 1; x > w - 11 && x >= 0; x--) {
          final pixel = processed.getPixel(x, y);
          totalLuminance += img.getLuminance(pixel).toInt();
          borderCount++;
        }
      }

      final avgBgLuminance = borderCount > 0 ? totalLuminance / borderCount : 240.0;

      // If background is too dark, we cannot confidently identify signature paper background
      if (avgBgLuminance < 140) {
        return CleanedSignatureResult(
          cleanedBytes: params.originalBytes,
          success: false,
          errorMessage: 'Automatic cleanup could not confidently remove the background (Background too dark).',
        );
      }

      // Dynamic threshold: pixels with luminance close to or above avgBgLuminance are cleared
      // Signature strokes are generally darker. Let's make anything with luminance > (avgBgLuminance - 35) transparent.
      final threshold = (avgBgLuminance - 35).clamp(120.0, 235.0);

      // Create a transparent image with same dimensions
      final cleanedImage = img.Image(width: w, height: h, numChannels: 4);

      int minX = w;
      int maxX = 0;
      int minY = h;
      int maxY = 0;
      bool hasInk = false;

      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final pixel = processed.getPixel(x, y);
          final r = pixel.r.toInt();
          final g = pixel.g.toInt();
          final b = pixel.b.toInt();
          
          final lum = img.getLuminance(pixel);

          if (lum > threshold) {
            // Background -> Transparent
            cleanedImage.setPixelRgba(x, y, 0, 0, 0, 0);
          } else {
            // Ink -> Keep ink color and apply alpha opacity to clean stroke edges
            final factor = (threshold - lum) / threshold; // 0 to 1
            final alpha = (factor * 350).clamp(0, 255).toInt();
            
            cleanedImage.setPixelRgba(x, y, r, g, b, alpha);

            // Record bounding box for auto cropping
            if (alpha > 40) {
              if (x < minX) minX = x;
              if (x > maxX) maxX = x;
              if (y < minY) minY = y;
              if (y > maxY) maxY = y;
              hasInk = true;
            }
          }
        }
      }

      if (!hasInk) {
        return CleanedSignatureResult(
          cleanedBytes: params.originalBytes,
          success: false,
          errorMessage: 'Automatic cleanup could not confidently identify signature lines.',
        );
      }

      // 3. Auto cropping with a safe margin
      const margin = 20;
      final cropX = (minX - margin).clamp(0, w - 1);
      final cropY = (minY - margin).clamp(0, h - 1);
      final cropW = (maxX - minX + margin * 2).clamp(1, w - cropX);
      final cropH = (maxY - minY + margin * 2).clamp(1, h - cropY);

      final croppedImage = img.copyCrop(cleanedImage, x: cropX, y: cropY, width: cropW, height: cropH);
      final encodedPng = Uint8List.fromList(img.encodePng(croppedImage));

      return CleanedSignatureResult(
        cleanedBytes: encodedPng,
        success: true,
      );
    } catch (e) {
      return CleanedSignatureResult(
        cleanedBytes: params.originalBytes,
        success: false,
        errorMessage: 'Image processing error: $e',
      );
    }
  }
}
