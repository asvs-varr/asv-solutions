// BANAAG Smart Lighting Sizer Engine
// Computes recommended luminous flux and LED fixtures based on PEC & IESNA standards.

enum RoomType {
  livingDining('Living & Dining', 150),
  kitchen('Kitchen / Food Prep', 300),
  bedroom('Bedroom / Resting', 120),
  bathroom('Bathroom / Powder Room', 200),
  homeOffice('Home Office / Study Area', 400),
  garageStorage('Garage / Outdoor / Utility', 100);

  final String label;
  final int recommendedLux; // Lumens per square meter
  const RoomType(this.label, this.recommendedLux);
}

class LightingRecommendation {
  final RoomType roomType;
  final double roomAreaSqm;
  final double targetLumens;
  final int recommendedWattagePerFixture;
  final int lumensPerFixture;
  final int fixtureCount;
  final double totalLightingVA;
  final String explanation;

  LightingRecommendation({
    required this.roomType,
    required this.roomAreaSqm,
    required this.targetLumens,
    required this.recommendedWattagePerFixture,
    required this.lumensPerFixture,
    required this.fixtureCount,
    required this.totalLightingVA,
    required this.explanation,
  });
}

class LightingEngine {
  LightingEngine._();

  /// Calculates recommended lighting fixtures for a room
  static LightingRecommendation calculate({
    required RoomType roomType,
    required double areaSqm,
    double ceilingHeightMeters = 2.7,
  }) {
    final double safeArea = areaSqm <= 0 ? 12.0 : areaSqm;
    final int lux = roomType.recommendedLux;
    
    // Ceiling height correction factor (standard residential is 2.7m)
    double heightFactor = 1.0;
    if (ceilingHeightMeters > 3.0) {
      heightFactor = 1.15; // 15% more lumens needed for high ceilings
    }

    final double totalTargetLumens = safeArea * lux * heightFactor;

    // Standard high-efficiency LED Downlight benchmark: 12W = ~900 Lumens (75-80 lm/W)
    const int lampWatts = 12;
    const int lumensPerLamp = 900;

    int fixtures = (totalTargetLumens / lumensPerLamp).ceil();
    if (fixtures < 1) fixtures = 1;

    // 12W LED fixture with power factor ~0.9 = ~15 VA connected load
    final double totalVA = fixtures * 15.0;

    final explanation =
        'Batay sa PEC & IESNA ($lux Lux para sa ${roomType.label}), kailangan ng humigit-kumulang ${totalTargetLumens.toStringAsFixed(0)} lumens. '
        'Inirerekomenda ang $fixtures pcs $lampWatts W LED Downlights ($lumensPerLamp lm bawat isa).';

    return LightingRecommendation(
      roomType: roomType,
      roomAreaSqm: safeArea,
      targetLumens: totalTargetLumens,
      recommendedWattagePerFixture: lampWatts,
      lumensPerFixture: lumensPerLamp,
      fixtureCount: fixtures,
      totalLightingVA: totalVA,
      explanation: explanation,
    );
  }
}
