import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:image/image.dart' as img;

class DocumentExtractionResult {
  final String rawText;
  final String engine;
  final bool isScanned;
  final int pageCount;

  const DocumentExtractionResult({
    required this.rawText,
    required this.engine,
    required this.isScanned,
    this.pageCount = 1,
  });
}

class DocumentTextExtractor {
  static final DocumentTextExtractor instance = DocumentTextExtractor._internal();
  DocumentTextExtractor._internal();

  /// Calculate SHA-256 hash of a file for duplicate detection
  Future<String> calculateFileHash(File file) async {
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Unified text extraction method
  Future<DocumentExtractionResult> extractText(File file) async {
    final filePath = file.path;
    final ext = path.extension(filePath).toLowerCase().replaceAll('.', '');

    if (ext == 'pdf') {
      return await _processPdfFile(filePath);
    } else if (['jpg', 'jpeg', 'png'].contains(ext)) {
      return await _processImageFile(filePath);
    } else {
      return const DocumentExtractionResult(
        rawText: '',
        engine: 'unsupported',
        isScanned: false,
      );
    }
  }

  /// PDF Text Extraction function
  Future<DocumentExtractionResult> _processPdfFile(String filePath) async {
    try {
      final file = File(filePath);
      final Uint8List bytes = await file.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      final int pageCount = document.pages.count;

      final PdfTextExtractor extractor = PdfTextExtractor(document);
      final String extractedText = extractor.extractText();
      document.dispose();

      final cleanText = extractedText.trim();

      if (cleanText.length > 40 && cleanText.contains(RegExp(r'[a-zA-Z0-9]'))) {
        return DocumentExtractionResult(
          rawText: cleanText,
          engine: 'syncfusion_pdf_native',
          isScanned: false,
          pageCount: pageCount,
        );
      } else {
        // Fallback for scanned PDF without text layer
        return DocumentExtractionResult(
          rawText: 'Scanned PDF document - Text layer is empty or non-selectable.',
          engine: 'pdf_image_ocr_fallback',
          isScanned: true,
          pageCount: pageCount,
        );
      }
    } catch (e) {
      debugPrint('Error extracting PDF text: $e');
      return DocumentExtractionResult(
        rawText: 'Error parsing PDF file: $e',
        engine: 'error_fallback',
        isScanned: false,
      );
    }
  }

  /// Image Text Extraction using Windows Native OCR (Windows.Media.Ocr)
  Future<DocumentExtractionResult> _processImageFile(String filePath) async {
    try {
      if (!Platform.isWindows) {
        return const DocumentExtractionResult(
          rawText: 'Image OCR is currently supported on Windows devices.',
          engine: 'non_windows_fallback',
          isScanned: true,
        );
      }

      // Preprocess image: Grayscale & Contrast enhancement for better OCR accuracy
      String targetPath = filePath;
      try {
        final rawFile = File(filePath);
        final bytes = await rawFile.readAsBytes();
        final decoded = img.decodeImage(bytes);
        if (decoded != null) {
          final grayscale = img.grayscale(decoded);
          final enhanced = img.adjustColor(grayscale, contrast: 1.25, brightness: 1.05);
          final tempDir = Directory.systemTemp;
          final processedPath = path.join(tempDir.path, 'ocr_prep_${DateTime.now().millisecondsSinceEpoch}.png');
          final processedFile = File(processedPath);
          await processedFile.writeAsBytes(img.encodePng(enhanced));
          targetPath = processedPath;
        }
      } catch (e) {
        debugPrint('Preprocessing image note: $e');
      }

      // Execute Windows Native OCR PowerShell Script
      final scriptPath = path.join(Directory.current.path, 'lib', 'services', 'win_ocr.ps1');
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', scriptPath,
        '-ImagePath', targetPath,
      ]);

      final stdout = result.stdout.toString().trim();
      final stderr = result.stderr.toString().trim();

      if (stdout.isNotEmpty && !stdout.startsWith('ERROR:')) {
        return DocumentExtractionResult(
          rawText: stdout,
          engine: 'windows_native_ocr',
          isScanned: true,
        );
      } else if (stdout.startsWith('ERROR:')) {
        debugPrint('Windows Native OCR warning: $stdout');
        return DocumentExtractionResult(
          rawText: stdout,
          engine: 'windows_native_ocr_error',
          isScanned: true,
        );
      } else {
        debugPrint('Windows Native OCR stderr: $stderr');
        return DocumentExtractionResult(
          rawText: stderr.isNotEmpty ? stderr : 'No text could be extracted from image.',
          engine: 'windows_native_ocr_empty',
          isScanned: true,
        );
      }
    } catch (e) {
      debugPrint('Error extracting image text: $e');
      return DocumentExtractionResult(
        rawText: 'Error running image OCR: $e',
        engine: 'error_fallback',
        isScanned: true,
      );
    }
  }
}
