// BANAAG Core Domain: Floor Plan Room Space Scanner Engine
// Uses Google ML Kit on-device Text Recognition (100% offline) to extract
// room names and square meters from architectural blueprints and floor plans.

import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'models.dart';
import 'pdf_blueprint_engine.dart';

class FloorPlanScannerEngine {
  /// Scans a floor plan from either an Image file or a PDF Blueprint.
  /// If a PDF is provided, it automatically extracts and renders the selected sheet page.
  static Future<List<RoomSpace>> scanFloorPlan(String path, {int pdfPageIndex = 0}) async {
    String imageToScan = path;
    if (PdfBlueprintEngine.isPdf(path)) {
      final rendered = await PdfBlueprintEngine.renderPdfPageToImage(path, pageIndex: pdfPageIndex);
      if (rendered != null) {
        imageToScan = rendered;
      } else {
        return [];
      }
    }
    return scanFloorPlanImage(imageToScan);
  }

  /// Scans a local floor plan image or photo on-device.
  /// Extracts rooms with their names, detected areas (m²), and default ceiling heights.
  static Future<List<RoomSpace>> scanFloorPlanImage(String imagePath) async {
    final file = File(imagePath);
    if (!file.existsSync()) {
      return [];
    }

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      final List<RoomSpace> detectedRooms = _parseRecognizedText(recognizedText);
      return detectedRooms;
    } catch (_) {
      return [];
    }
  }

  /// Parses text blocks and lines looking for room names and area notations
  static List<RoomSpace> _parseRecognizedText(RecognizedText recognizedText) {
    final List<RoomSpace> rooms = [];

    // Common room keywords in blueprints
    final roomKeywords = [
      'living room',
      'living',
      'dining room',
      'dining',
      'kitchen',
      'master bedroom',
      'bedroom',
      'bathroom',
      'toilet & bath',
      't&b',
      'hallway',
      'hall',
      'balcony',
      'porch',
      'terrace',
      'garage',
      'carport',
      'laundry',
      'service area',
      'utility',
      'foyer',
      'entry',
      'closet',
      'office',
      'study',
    ];

    // Regex to detect area numbers: e.g. "23.81 m²", "23.51 m2", "12.52 sqm", "8.40m²", "7.04 m^2"
    final areaRegex = RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*(?:m²|m2|sqm|sq\.m|\^2|m\^2)', caseSensitive: false);

    // 1. First Pass: Check lines within blocks where room title and area are close together
    for (final block in recognizedText.blocks) {
      final blockLines = block.lines.map((l) => l.text.trim()).toList();
      for (int i = 0; i < blockLines.length; i++) {
        final line = blockLines[i];
        final lower = line.toLowerCase();

        String? matchedKeyword;
        for (final kw in roomKeywords) {
          if (lower.contains(kw)) {
            matchedKeyword = kw;
            break;
          }
        }

        if (matchedKeyword != null) {
          double detectedArea = 0.0;

          // Check if area is on the same line: e.g., "Kitchen 23.51 m²"
          final matchSame = areaRegex.firstMatch(line);
          if (matchSame != null) {
            detectedArea = double.tryParse(matchSame.group(1) ?? '0') ?? 0.0;
          } else if (i + 1 < blockLines.length) {
            // Check next line: e.g., line 1 = "Kitchen", line 2 = "23.51 m²"
            final nextLine = blockLines[i + 1];
            final matchNext = areaRegex.firstMatch(nextLine);
            if (matchNext != null) {
              detectedArea = double.tryParse(matchNext.group(1) ?? '0') ?? 0.0;
            } else {
              // Also check raw number on next line (e.g. "23.51")
              final numRegex = RegExp(r'^([0-9]+(?:\.[0-9]+)?)$');
              final matchNum = numRegex.firstMatch(nextLine.trim());
              if (matchNum != null) {
                detectedArea = double.tryParse(matchNum.group(1) ?? '0') ?? 0.0;
              }
            }
          }

          final formattedName = _formatRoomName(line, matchedKeyword, rooms.length + 1);
          final defaultArea = detectedArea > 0 ? detectedArea : _fallbackAreaForKeyword(matchedKeyword);

          // Avoid immediate duplicates
          final alreadyExists = rooms.any((r) => r.name.toLowerCase() == formattedName.toLowerCase() && (r.areaSqm - defaultArea).abs() < 0.1);
          if (!alreadyExists) {
            rooms.add(RoomSpace(
              id: 'sp-scan-${rooms.length + 1}',
              name: formattedName,
              areaSqm: defaultArea,
              ceilingHeight: 2.7,
            ));
          }
        }
      }
    }

    // 2. Second Pass: If blocks were separate, scan all lines flat
    if (rooms.isEmpty) {
      final allLines = recognizedText.text.split(RegExp(r'[\r\n]+')).map((s) => s.trim()).toList();
      for (int i = 0; i < allLines.length; i++) {
        final line = allLines[i];
        final lower = line.toLowerCase();
        for (final kw in roomKeywords) {
          if (lower.contains(kw)) {
            double detectedArea = 0.0;
            final match = areaRegex.firstMatch(line);
            if (match != null) {
              detectedArea = double.tryParse(match.group(1) ?? '0') ?? 0.0;
            } else if (i + 1 < allLines.length) {
              final matchNext = areaRegex.firstMatch(allLines[i + 1]);
              if (matchNext != null) {
                detectedArea = double.tryParse(matchNext.group(1) ?? '0') ?? 0.0;
              }
            }
            final name = _formatRoomName(line, kw, rooms.length + 1);
            final area = detectedArea > 0 ? detectedArea : _fallbackAreaForKeyword(kw);
            if (!rooms.any((r) => r.name.toLowerCase() == name.toLowerCase())) {
              rooms.add(RoomSpace(
                id: 'sp-scan-${rooms.length + 1}',
                name: name,
                areaSqm: area,
                ceilingHeight: 2.7,
              ));
            }
            break;
          }
        }
      }
    }

    return rooms;
  }

  static String _formatRoomName(String rawLine, String keyword, int index) {
    final clean = rawLine.replaceAll(RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*(?:m²|m2|sqm|sq\.m|\^2|m\^2)', caseSensitive: false), '').trim();
    if (clean.length >= 3 && clean.length <= 25) {
      // Capitalize words
      return clean.split(' ').map((w) {
        if (w.isEmpty) return '';
        return w[0].toUpperCase() + (w.length > 1 ? w.substring(1).toLowerCase() : '');
      }).join(' ');
    }

    // Fallback to formatted keyword
    final words = keyword.split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
    if (keyword == 'bedroom') {
      return '$words $index';
    }
    return words;
  }

  static double _fallbackAreaForKeyword(String kw) {
    switch (kw) {
      case 'living room':
      case 'living':
        return 22.0;
      case 'kitchen':
        return 14.0;
      case 'dining room':
      case 'dining':
        return 12.0;
      case 'master bedroom':
        return 16.0;
      case 'bedroom':
        return 10.0;
      case 'bathroom':
      case 'toilet & bath':
      case 't&b':
        return 5.0;
      case 'hallway':
      case 'hall':
        return 4.0;
      case 'balcony':
        return 6.0;
      case 'garage':
      case 'carport':
        return 15.0;
      default:
        return 10.0;
    }
  }

  /// Preset rooms specifically for standard Philippine residential reference plans
  static List<RoomSpace> getDefaultReferenceRooms() {
    return [
      RoomSpace(id: 'sp-ref-1', name: 'Living Room', areaSqm: 23.81, ceilingHeight: 2.7),
      RoomSpace(id: 'sp-ref-2', name: 'Kitchen', areaSqm: 23.51, ceilingHeight: 2.7),
      RoomSpace(id: 'sp-ref-3', name: 'Master Bedroom', areaSqm: 12.52, ceilingHeight: 2.7),
      RoomSpace(id: 'sp-ref-4', name: 'Bedroom 2', areaSqm: 8.40, ceilingHeight: 2.7),
      RoomSpace(id: 'sp-ref-5', name: 'Bathroom', areaSqm: 7.04, ceilingHeight: 2.7),
      RoomSpace(id: 'sp-ref-6', name: 'Hall', areaSqm: 3.52, ceilingHeight: 2.7),
    ];
  }
}
