import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:banaag/domain/models.dart';

void main() {
  group('BANAAG 2-Point Millimeter Scale Calibration Mathematical Tests', () {
    test('Calculates exact pixelsPerMeter and millimeters from 2 CAD pin points', () {
      final pinA = const math.Point<double>(50.0, 100.0);
      final pinB = const math.Point<double>(250.0, 100.0);

      // Pixel distance along horizontal wall
      final double pixelDistance = pinA.distanceTo(pinB); // 200.0 px
      expect(pixelDistance, equals(200.0));

      // Known physical wall dimension: 6,000 mm (= 6.0 meters)
      const double knownDistanceMm = 6000.0;
      const double knownDistanceMeters = knownDistanceMm / 1000.0;

      // Scale factor: pixels per meter
      final double pixelsPerMeter = pixelDistance / knownDistanceMeters;
      expect(pixelsPerMeter, closeTo(33.333, 0.001));

      // Inverse verification: test conduit route between 2 points (e.g. 150 px run)
      const double testConduitPixels = 150.0;
      final double calculatedMeters = testConduitPixels / pixelsPerMeter;
      final double calculatedMm = calculatedMeters * 1000.0;

      expect(calculatedMeters, closeTo(4.50, 0.01));
      expect(calculatedMm, closeTo(4500.0, 1.0));
    });

    test('RoomSpace model supports non-square L-Shape and Custom shapes with cutouts', () {
      final room = RoomSpace(
        id: 'sp-test',
        name: 'Master Bed with Walk-in Closet',
        areaSqm: 18.5,
        ceilingHeight: 2.7,
        shapeType: 'L_SHAPE',
        cutoutWidth: 1.8,
        cutoutDepth: 2.2,
      );

      final json = room.toJson();
      expect(json['shapeType'], equals('L_SHAPE'));
      expect(json['cutoutWidth'], equals(1.8));
      expect(json['cutoutDepth'], equals(2.2));

      final restored = RoomSpace.fromJson(json);
      expect(restored.shapeType, equals('L_SHAPE'));
      expect(restored.cutoutWidth, equals(1.8));
      expect(restored.cutoutDepth, equals(2.2));
    });
  });
}
