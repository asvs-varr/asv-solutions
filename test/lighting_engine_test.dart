// BANAAG Lighting Engine Tests
// Verifies PEC & IESNA standard lux computations and fixture recommendations

import 'package:flutter_test/flutter_test.dart';
import 'package:banaag/domain/lighting_engine.dart';

void main() {
  group('BANAAG Smart Lighting Engine Tests', () {
    test('Calculates kitchen lighting fixtures correctly (300 Lux standard)', () {
      final rec = LightingEngine.calculate(
        roomType: RoomType.kitchen,
        areaSqm: 15.0, // 15 sqm kitchen
        ceilingHeightMeters: 2.7,
      );

      // Target lumens = 15 sqm * 300 lux = 4500 lm
      expect(rec.targetLumens, 4500.0);
      // 4500 lm / 900 lm per 12W LED downlight = 5 fixtures
      expect(rec.fixtureCount, 5);
      expect(rec.recommendedWattagePerFixture, 12);
      expect(rec.totalLightingVA, 5 * 15.0); // 75 VA connected load
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
