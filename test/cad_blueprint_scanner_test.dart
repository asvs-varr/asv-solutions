import 'package:flutter_test/flutter_test.dart';
import 'package:banaag/domain/floor_plan_scanner_engine.dart';
import 'package:banaag/domain/models.dart';

void main() {
  group('CAD Blueprint Scanner Engine Tests', () {
    test('Institutional Reference Rooms match TESDA 3rd Floor blueprint proportions', () {
      final rooms = FloorPlanScannerEngine.getInstitutionalReferenceRooms(
        widthMeters: 15.5,
        lengthMeters: 18.48,
      );

      expect(rooms.length, equals(5));

      final functionHall = rooms.firstWhere((r) => r.name.contains('Function Hall'));
      expect(functionHall.areaSqm, closeTo(79.91, 0.1));
      expect(functionHall.shapeType, equals('L_SHAPE'));

      final office = rooms.firstWhere((r) => r.name.contains('Office'));
      expect(office.areaSqm, closeTo(46.10, 0.1));

      final staff = rooms.firstWhere((r) => r.name.contains('Staff'));
      expect(staff.areaSqm, closeTo(11.55, 0.1));

      final corridor = rooms.firstWhere((r) => r.name.contains('Corridor'));
      expect(corridor.areaSqm, closeTo(21.96, 0.1));

      final stairs = rooms.firstWhere((r) => r.name.contains('Stairs'));
      expect(stairs.areaSqm, closeTo(6.80, 0.1));

      final totalArea = rooms.fold<double>(0.0, (acc, r) => acc + r.areaSqm);
      expect(totalArea, closeTo(166.32, 0.5));
    });

    test('estimateAreaForLabel calculates correct CAD areas for institutional rooms', () {
      expect(FloorPlanScannerEngine.estimateAreaForLabel('Function Hall'), closeTo(79.91, 0.01));
      expect(FloorPlanScannerEngine.estimateAreaForLabel('Event Place'), closeTo(79.91, 0.01));
      expect(FloorPlanScannerEngine.estimateAreaForLabel('Office Rooms'), closeTo(46.10, 0.01));
      expect(FloorPlanScannerEngine.estimateAreaForLabel('Staff Room'), closeTo(11.55, 0.01));
      expect(FloorPlanScannerEngine.estimateAreaForLabel('Corridor'), closeTo(21.96, 0.01));
      expect(FloorPlanScannerEngine.estimateAreaForLabel('Landing / Stairs'), closeTo(6.80, 0.01));
    });

    test('FloorPlanScanResult defaults to CAD building dimensions', () {
      final result = FloorPlanScanResult(rooms: []);
      expect(result.detectedBuildingWidthMeters, equals(15.50));
      expect(result.detectedBuildingLengthMeters, equals(18.48));
      expect(result.candidateQuickAddTags, isEmpty);
    });
  });
}
