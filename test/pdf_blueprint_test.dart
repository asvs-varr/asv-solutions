import 'package:flutter_test/flutter_test.dart';
import 'package:banaag/domain/pdf_blueprint_engine.dart';
import 'package:banaag/domain/floor_plan_scanner_engine.dart';

void main() {
  group('BANAAG PDF Blueprint Engine & Floor Plan Scanner Unit Tests', () {
    test('PdfBlueprintEngine.isPdf detects PDF extensions case-insensitively', () {
      expect(PdfBlueprintEngine.isPdf('floor_plan.pdf'), isTrue);
      expect(PdfBlueprintEngine.isPdf('BLUEPRINT_E1.PDF'), isTrue);
      expect(PdfBlueprintEngine.isPdf('plan.PDF'), isTrue);
      expect(PdfBlueprintEngine.isPdf('image.png'), isFalse);
      expect(PdfBlueprintEngine.isPdf('blueprint.jpg'), isFalse);
      expect(PdfBlueprintEngine.isPdf(''), isFalse);
      expect(PdfBlueprintEngine.isPdf(null), isFalse);
    });

    test('FloorPlanScannerEngine fallback reference rooms provide complete residential coverage', () {
      final defaultRooms = FloorPlanScannerEngine.getDefaultReferenceRooms();
      expect(defaultRooms.isNotEmpty, isTrue);

      final roomNames = defaultRooms.map((r) => r.name.toLowerCase()).toList();
      expect(roomNames.any((n) => n.contains('living')), isTrue);
      expect(roomNames.any((n) => n.contains('kitchen')), isTrue);
      expect(roomNames.any((n) => n.contains('bedroom')), isTrue);
      expect(roomNames.any((n) => n.contains('bath')), isTrue);

      // Verify all default rooms have positive areas and standard ceiling heights
      for (final room in defaultRooms) {
        expect(room.areaSqm, greaterThan(0.0));
        expect(room.ceilingHeight, greaterThanOrEqualTo(2.4)); // PEC minimum habitable ceiling height
      }
    });

    test('FloorPlanScannerEngine handles invalid / missing file gracefully', () async {
      final rooms = await FloorPlanScannerEngine.scanFloorPlan('non_existent_file.pdf');
      expect(rooms, isEmpty);
    });
  });
}
