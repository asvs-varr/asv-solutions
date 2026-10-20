// BANAAG Lighting Engine Tests
// Verifies PEC & IESNA standard lux computations and fixture recommendations

import 'package:flutter_test/flutter_test.dart';
import 'package:banaag/domain/lighting_engine.dart';

void main() {
  group('BANAAG Smart Lighting Engine Tests', () {
    test('Calculates kitchen lighting fixtures correctly (250 Lux standard)', () {
      final rec = LightingEngine.calculate(
        roomType: RoomType.kitchen,
        areaSqm: 15.0, // 15 sqm kitchen
        ceilingHeightMeters: 2.7,
      );

      // Target lumens = (15 sqm * 250 lux) / 0.75 = 5000 lm
      expect(rec.targetLumens, 5000.0);
      // 15 sqm kitchen recommends 3 fixtures of 15W High-CRI Kitchen LED Downlight
      expect(rec.fixtureCount, 3);
      expect(rec.recommendedWattagePerFixture, 15);
      expect(rec.primaryFixtureName, 'High-CRI Kitchen LED Downlight');
      expect(rec.extraFixtures.isNotEmpty, true);
    });

    test('Applies high-ceiling correction factor (>3.0m)', () {
      final normal = LightingEngine.calculate(
        roomType: RoomType.livingDining,
        areaSqm: 20.0,
        ceilingHeightMeters: 2.7,
      );

      final highCeiling = LightingEngine.calculate(
        roomType: RoomType.livingDining,
        areaSqm: 20.0,
        ceilingHeightMeters: 3.5, // Cathedral / high drop ceiling
      );

      expect(highCeiling.targetLumens, greaterThan(normal.targetLumens));
    });
  });
}
