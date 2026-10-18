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

enum LightingTier {
  standard('Standard Minimum', 'PEC & IESNA bare minimum code compliance', 1.0),
  premium('Premium Enhanced', 'Cove lighting + Dimmable tri-color smart illumination', 1.35),
  luxury('Luxury Architectural', 'Full layered lighting: Downlights + Accent Cove + Magnetic Track Spotlights', 1.70);

  final String label;
  final String description;
  final double lumenMultiplier;
  const LightingTier(this.label, this.description, this.lumenMultiplier);
}

class LightingRecommendation {
  final RoomType roomType;
  final LightingTier tier;
  final double roomAreaSqm;
  final double targetLumens;
  final int recommendedWattagePerFixture;
  final int lumensPerFixture;
  final int fixtureCount;
  final double totalLightingVA;
  final String explanation;
  final List<Map<String, dynamic>> extraFixtures;

  LightingRecommendation({
    required this.roomType,
    this.tier = LightingTier.standard,
    required this.roomAreaSqm,
    required this.targetLumens,
    required this.recommendedWattagePerFixture,
    required this.lumensPerFixture,
    required this.fixtureCount,
    required this.totalLightingVA,
    required this.explanation,
    this.extraFixtures = const [],
  });
}

class LightingEngine {
  LightingEngine._();

  /// Calculates recommended lighting fixtures for a room based on Tier
  static LightingRecommendation calculate({
    required RoomType roomType,
    required double areaSqm,
    double ceilingHeightMeters = 2.7,
    LightingTier tier = LightingTier.standard,
  }) {
    final double safeArea = areaSqm <= 0 ? 12.0 : areaSqm;
    final int lux = roomType.recommendedLux;
    
    // Ceiling height correction factor (standard residential is 2.7m)
    double heightFactor = 1.0;
    if (ceilingHeightMeters > 3.0) {
      heightFactor = 1.15; // 15% more lumens needed for high ceilings
    }

    final double totalTargetLumens = safeArea * lux * heightFactor * tier.lumenMultiplier;

    // Standard high-efficiency LED Downlight benchmark: 12W = ~900 Lumens (75-80 lm/W)
    const int lampWatts = 12;
    const int lumensPerLamp = 900;

    int fixtures = (totalTargetLumens / lumensPerLamp).ceil();
    if (fixtures < 1) fixtures = 1;

    double totalVA = fixtures * 15.0;
    final List<Map<String, dynamic>> extraFixtures = [];

    if (tier == LightingTier.premium) {
      // Add Architectural Cove Light / LED Strip
      final coveWatts = (safeArea * 4.0).clamp(30.0, 120.0);
      extraFixtures.add({
        'name': 'Architectural LED Cove / Accent Strip (Warm White)',
        'watts': coveWatts.round(),
        'va': coveWatts * 1.15,
        'citation': 'PEC Art 4.10 / IESNA Layered Design',
      });
      totalVA += coveWatts * 1.15;
    } else if (tier == LightingTier.luxury) {
      // Add Full Layered System: Cove Light + Magnetic Track / Gimbal Eyeball Spotlights
      final coveWatts = (safeArea * 4.5).clamp(40.0, 150.0);
      extraFixtures.add({
        'name': 'Perimeter Architectural LED Cove Strip (Dimmable Tri-Color)',
        'watts': coveWatts.round(),
        'va': coveWatts * 1.15,
        'citation': 'PEC Art 4.10.12 (Concealed Luminaires)',
      });
      final trackSpots = (safeArea / 6.0).ceil().clamp(2, 6);
      extraFixtures.add({
        'name': 'Magnetic Track / Gimbal Accent Spotlights ($trackSpots pcs)',
        'watts': trackSpots * 10,
        'va': trackSpots * 12.0,
        'citation': 'PEC Art 4.10.14 (Track Lighting)',
      });
      totalVA += (coveWatts * 1.15) + (trackSpots * 12.0);
    }

    final extraNote = extraFixtures.isNotEmpty ? ' Kasama ang ${extraFixtures.length} architectural accent layers.' : '';
    final explanation =
        'Batay sa ${tier.label} ($lux Lux benchmark para sa ${roomType.label}), kailangan ng humigit-kumulang ${totalTargetLumens.toStringAsFixed(0)} lumens. '
        'Pangunahing ilaw: $fixtures pcs $lampWatts W LED Downlights ($lumensPerLamp lm bawat isa).$extraNote';

    return LightingRecommendation(
      roomType: roomType,
      tier: tier,
      roomAreaSqm: safeArea,
      targetLumens: totalTargetLumens,
      recommendedWattagePerFixture: lampWatts,
      lumensPerFixture: lumensPerLamp,
      fixtureCount: fixtures,
      totalLightingVA: totalVA,
      explanation: explanation,
      extraFixtures: extraFixtures,
    );
  }
}
