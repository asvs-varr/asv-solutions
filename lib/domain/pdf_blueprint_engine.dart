// BANAAG Core Domain: PDF Blueprint Rasterizer & Page Selector Engine
// Converts PDF architectural blueprints into high-resolution images for
// ML Kit optical OCR text extraction and Plan Canvas architectural underlays.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
        // Check if there is an embedded CAD building footprint to auto-crop to tight viewport
        final cropRect = detectCadBuildingFootprintNormalized(bytes);
        if (cropRect != null) {
          final croppedBytes = await cropImageBytes(pngBytes, cropRect);
          if (croppedBytes != null && croppedBytes.isNotEmpty) {
            await outFile.writeAsBytes(croppedBytes, flush: true);
            return outPath;
          }
        }
        await outFile.writeAsBytes(pngBytes, flush: true);
        return outPath;
      }

      return null;
    } catch (e) {
      debugPrint('PdfBlueprintEngine.renderPdfPageToImage error: $e');
      return null;
    }
  }

  /// Automatically computes the tight bounding box around the actual CAD floor plan
  /// within an architectural sheet (filtering out title blocks, border margins, and blank space).
  static Rect? detectCadBuildingFootprintNormalized(Uint8List pdfBytes) {
    try {
      final String rawPdf = latin1.decode(pdfBytes);
      final streamMatches = RegExp(r'stream\r?\n([\s\S]*?)\r?\nendstream').allMatches(rawPdf);

      final Map<String, String> cmap = {};
      final cmapMatches = RegExp(r'beginbfchar([\s\S]*?)endbfchar').allMatches(rawPdf);
      for (final block in cmapMatches) {
        final bStr = block.group(1) ?? '';
        final charMatches = RegExp(r'<([0-9a-fA-F]+)>\s*<([0-9a-fA-F]+)>').allMatches(bStr);
        for (final cm in charMatches) {
          final src = cm.group(1)!.toLowerCase();
          final dstHex = cm.group(2)!;
          final codePoint = int.tryParse(dstHex, radix: 16);
          if (codePoint != null) {
            cmap[src] = String.fromCharCode(codePoint);
          }
        }
      }

      final List<Offset> roomPoints = [];
      for (final sm in streamMatches) {
        final raw = sm.group(1);
        if (raw == null) continue;
        Uint8List? decomp;
        try {
          decomp = Uint8List.fromList(zlib.decode(latin1.encode(raw)));
        } catch (_) {}
        if (decomp != null) {
          final dStr = latin1.decode(decomp);
          final tmMatches = RegExp(r'1\s+0\s+0\s+1\s+([0-9\.\-]+)\s+([0-9\.\-]+)\s+Tm[\s\S]*?<([0-9a-fA-F]+)>\s*Tj').allMatches(dStr);
          for (final tm in tmMatches) {
            final double? x = double.tryParse(tm.group(1) ?? '');
            final double? y = double.tryParse(tm.group(2) ?? '');
            final h = tm.group(3) ?? '';
            if (x != null && y != null) {
              final StringBuffer sb = StringBuffer();
              for (int j = 0; j < h.length; j += 4) {
                if (j + 4 <= h.length) {
                  final chunk = h.substring(j, j + 4).toLowerCase();
                  sb.write(cmap[chunk] ?? '');
                }
              }
              final txt = sb.toString().toLowerCase();
              final isRoomText = txt.contains('hall') ||
                  txt.contains('room') ||
                  txt.contains('office') ||
                  txt.contains('staff') ||
                  txt.contains('landing') ||
                  txt.contains('stairs') ||
                  txt.contains('storage');
              // Include outer dimension callouts (e.g. 15500, 4000, 4800, 3400, 3300, 19480)
              final isDimensionCallout = RegExp(r'^\d{4,5}$').hasMatch(txt.trim());
              if (isRoomText || isDimensionCallout) {
                roomPoints.add(Offset(x, y));
              }
            }
          }
        }
      }

      if (roomPoints.isNotEmpty) {
        double minX = roomPoints.map((p) => p.dx).reduce(math.min);
        double maxX = roomPoints.map((p) => p.dx).reduce(math.max);
        double minY = roomPoints.map((p) => p.dy).reduce(math.min);
        double maxY = roomPoints.map((p) => p.dy).reduce(math.max);

        // Generous margins so top dimension strings (4000, 4800, 3400, 3300, 15500)
        // and right/bottom dimension callouts have ample breathing space and are never clipped!
        final double envX1 = (minX - 1800.0).clamp(0.0, 14000.0);
        final double envX2 = (maxX + 1400.0).clamp(envX1 + 1000.0, 14000.0);
        final double envY1 = (minY - 1800.0).clamp(0.0, 9921.0);
        final double envY2 = (maxY + 1800.0).clamp(envY1 + 1000.0, 9921.0);

        final double normLeft = envX1 / 14000.0;
        final double normRight = envX2 / 14000.0;
        final double normTop = 1.0 - (envY2 / 9921.0);
        final double normBottom = 1.0 - (envY1 / 9921.0);

        return Rect.fromLTRB(
          normLeft.clamp(0.0, 1.0),
          normTop.clamp(0.0, 1.0),
          normRight.clamp(0.0, 1.0),
          normBottom.clamp(0.0, 1.0),
        );
      }
    } catch (_) {}
    return null;
  }

  /// Crops an image byte array using native dart:ui
  static Future<Uint8List?> cropImageBytes(Uint8List imageBytes, Rect normalizedCropRect) async {
    try {
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final int origW = image.width;
      final int origH = image.height;

      final int cropLeft = (origW * normalizedCropRect.left).round().clamp(0, origW - 1);
      final int cropTop = (origH * normalizedCropRect.top).round().clamp(0, origH - 1);
      final int cropWidth = (origW * normalizedCropRect.width).round().clamp(10, origW - cropLeft);
      final int cropHeight = (origH * normalizedCropRect.height).round().clamp(10, origH - cropTop);

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, cropWidth.toDouble(), cropHeight.toDouble()));

      // Composite onto crisp white background so hairline vector linework is ultra high contrast
      final bgPaint = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
      canvas.drawRect(ui.Rect.fromLTWH(0, 0, cropWidth.toDouble(), cropHeight.toDouble()), bgPaint);

      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(cropLeft.toDouble(), cropTop.toDouble(), cropWidth.toDouble(), cropHeight.toDouble()),
        ui.Rect.fromLTWH(0, 0, cropWidth.toDouble(), cropHeight.toDouble()),
        ui.Paint(),
      );

      final picture = recorder.endRecording();
      final croppedUiImage = await picture.toImage(cropWidth, cropHeight);
      final byteData = await croppedUiImage.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('cropImageBytes error: ');
      return null;
    }
  }
}
