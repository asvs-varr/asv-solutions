// BANAAG Core Domain: PDF Blueprint Rasterizer & Page Selector Engine
// Converts PDF architectural blueprints into high-resolution images for
// ML Kit optical OCR text extraction and Plan Canvas architectural underlays.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';

class PdfBlueprintPageInfo {
  final int pageIndex; // 0-based
  final int pageNumber; // 1-based
  final String label;
  final Uint8List? thumbnailBytes;

  PdfBlueprintPageInfo({
    required this.pageIndex,
    required this.pageNumber,
    required this.label,
    this.thumbnailBytes,
  });
}

class PdfBlueprintEngine {
  PdfBlueprintEngine._();

  /// Checks if a file path points to a PDF
  static bool isPdf(String? path) {
    if (path == null || path.isEmpty) return false;
    return path.toLowerCase().endsWith('.pdf');
  }

  /// Extracts the number of pages and thumbnail previews from a local PDF
  static Future<List<PdfBlueprintPageInfo>> getPdfPages(String pdfPath, {int maxPages = 15}) async {
    final file = File(pdfPath);
    if (!file.existsSync()) return [];

    try {
      final bytes = await file.readAsBytes();
      final List<PdfBlueprintPageInfo> pages = [];

      int index = 0;
      await for (final page in Printing.raster(bytes, dpi: 72.0)) {
        if (index >= maxPages) break;
        final png = await page.toPng();
        pages.add(PdfBlueprintPageInfo(
          pageIndex: index,
          pageNumber: index + 1,
          label: 'Sheet ${index + 1}',
          thumbnailBytes: png,
        ));
        index++;
      }
      return pages;
    } catch (e) {
      debugPrint('PdfBlueprintEngine.getPdfPages error: $e');
      return [];
    }
  }

  /// Renders a specific page of a PDF file to a high-resolution PNG on disk
  /// Returns the absolute path of the generated PNG file.
  static Future<String?> renderPdfPageToImage(
    String pdfPath, {
    int pageIndex = 0,
    double dpi = 150.0,
  }) async {
    final file = File(pdfPath);
    if (!file.existsSync()) return null;

    try {
      final bytes = await file.readAsBytes();
      final baseDir = file.parent.path;
      final rawName = file.uri.pathSegments.last.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
      final outPath = '$baseDir${Platform.pathSeparator}${rawName}_sheet_${pageIndex + 1}.png';

      final outFile = File(outPath);
      if (outFile.existsSync() && outFile.lengthSync() > 1024) {
        return outPath;
      }

      await for (final page in Printing.raster(bytes, pages: [pageIndex], dpi: dpi)) {
        final pngBytes = await page.toPng();
        await outFile.writeAsBytes(pngBytes, flush: true);
        return outPath;
      }

      return null;
    } catch (e) {
      debugPrint('PdfBlueprintEngine.renderPdfPageToImage error: $e');
      return null;
    }
  }
}
