// BANAAG Smart Lighting Sizer Engine
// Computes recommended luminous flux and LED fixtures based on PEC & IESNA standards.

enum RoomType {
  // Residential (PEC Table 2.20.2.3 & IESNA)
  livingDining('Living & Dining', 150),
  kitchen('Kitchen / Food Prep', 250),
  bedroom('Bedroom / Resting', 100),
  bathroom('Bathroom / Powder Room', 150),
  homeOffice('Home Office / Study Area', 300),
  garageStorage('Garage / Outdoor / Utility', 80),

  // Institutional (PEC 2017 & DOLE Rule 1075 / IESNA RP-3)
  classroom('Classroom / Lecture Hall', 400),
  workshop('Workshop / Welding & Tech-Voc Shop', 500),
  laboratory('Science & Computer Laboratory', 500),
  facultyOffice('Faculty & Administration Office', 350),

  // Commercial (PEC 2017 & DOLE Rule 1075 / IESNA RP-1)
  commercialRetail('Retail Store / Commercial Shop', 500),
  commercialRestaurant('Restaurant / Food Dining Area', 200),
  hallwayCorridor('Hallway & Passageway Corridor', 100);

  final String label;
  final int recommendedLux; // Lumens per square meter
  const RoomType(this.label, this.recommendedLux);
}

enum LightingTier {
  standard('Standard Minimum', 'PEC & IESNA bare minimum code compliance', 1.0),
  premium('Premium Enhanced', 'Cove lighting + Dimmable tri-color smart illumination', 1.25),
  luxury('Luxury Architectural', 'Full layered lighting: Downlights + Accent Cove + Magnetic Track Spotlights', 1.50);

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
  final String primaryFixtureName;
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
    required this.primaryFixtureName,
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

  /// Calculates recommended lighting fixtures for a room using realistic IESNA residential metrics:
  /// Target Lumens = Area * Lux * HeightFactor * TierMultiplier
  /// Uses Room-Specific Primary Fixtures (Pendant in Dining, Vanity in Bath, Under-Cabinet in Kitchen)
  static LightingRecommendation calculate({
    required RoomType roomType,
    required double areaSqm,
    double ceilingHeightMeters = 2.7,
    LightingTier tier = LightingTier.standard,
  }) {
    final double safeArea = areaSqm <= 0 ? 12.0 : areaSqm;
    final int lux = roomType.recommendedLux;
    
    // Ceiling height correction factor
    double heightFactor = 1.0;
    if (ceilingHeightMeters > 3.0) {
      heightFactor = 1.0 + ((ceilingHeightMeters - 3.0) * 0.10);
    }

    // Realistic Residential Target Lumens:
    // Direct LED illumination in residential settings with white ceilings/walls
    // Effective CU * LLF is ~0.75 for direct modern LED fixtures
    final double totalTargetLumens = (safeArea * lux * heightFactor * tier.lumenMultiplier) / 0.75;

    // Room-Specific Fixture Strategy & Dynamic Sizing:
    String primaryFixtureName = 'LED Downlight';
    int lampWatts = 12;
    int lumensPerLamp = 1000;
    int fixtures = 1;
    final List<Map<String, dynamic>> extraFixtures = [];

    switch (roomType) {
      case RoomType.bathroom:
        // Bathroom: 1 Moisture-proof Downlight/Ceiling Flush + 1 Mirror Vanity Light
        lampWatts = 9;
        lumensPerLamp = 750;
        fixtures = safeArea <= 5.0 ? 1 : 2;
        primaryFixtureName = 'IP65 Moisture-Proof LED Downlight';
        extraFixtures.add({
          'name': 'LED Mirror Vanity Task Light (4000K Neutral White)',
          'watts': 12,
          'va': 15.0,
          'citation': 'PEC Art 4.10 / IESNA Task Illuminance',
        });
        break;

      case RoomType.kitchen:
        // Kitchen: 2 to 4 Ceiling Downlights + Counter Under-Cabinet Task Lighting
        if (safeArea <= 8.0) {
          lampWatts = 12;
          lumensPerLamp = 1000;
          fixtures = 2;
        } else {
          lampWatts = 15;
          lumensPerLamp = 1350;
          fixtures = (safeArea / 5.0).round().clamp(2, 4);
        }
        primaryFixtureName = 'High-CRI Kitchen LED Downlight';
        extraFixtures.add({
          'name': 'Under-Cabinet Countertop LED Task Strip (Warm White)',
          'watts': 24,
          'va': 30.0,
          'citation': 'PEC Art 2.10.3.2 / Kitchen Task Lighting',
        });
        break;

      case RoomType.livingDining:
        // Living & Dining: Central Feature (Pendant/Fan Light) + Perimeter Accent Downlights
        if (safeArea <= 12.0) {
          lampWatts = 9;
          lumensPerLamp = 800;
          fixtures = 2;
        } else if (safeArea <= 20.0) {
          lampWatts = 9;
          lumensPerLamp = 800;
          fixtures = 4;
        } else {
          lampWatts = 12;
          lumensPerLamp = 1050;
          fixtures = (safeArea / 5.0).round().clamp(4, 8);
        }
        primaryFixtureName = 'Perimeter Warm LED Pinlight';
        extraFixtures.add({
          'name': 'Center Pendant Fixture / Ceiling Fan with LED Light (Warm White)',
          'watts': 40,
          'va': 50.0,
          'citation': 'IESNA Living & Dining Ambient Standards',
        });
        break;

      case RoomType.bedroom:
        // Bedroom: Comfort, non-glare illumination. Typically 1 center flush/pendant or 2-4 soft downlights
        if (safeArea <= 10.0) {
          lampWatts = 9;
          lumensPerLamp = 800;
          fixtures = 1; // 1 center light or 2 soft downlights is enough for <= 10 sqm
          primaryFixtureName = 'Soft Warm LED Ceiling Luminaire';
        } else if (safeArea <= 16.0) {
          lampWatts = 9;
          lumensPerLamp = 800;
          fixtures = 2;
          primaryFixtureName = 'Soft LED Recessed Downlight';
        } else {
          lampWatts = 12;
          lumensPerLamp = 1050;
          fixtures = 4;
          primaryFixtureName = 'Recessed LED Downlight';
        }
        break;

      case RoomType.homeOffice:
        // Home Office / Study: High lux task lighting (300 Lux)
        lampWatts = 12;
        lumensPerLamp = 1050;
        fixtures = (totalTargetLumens / lumensPerLamp).round().clamp(2, 6);
        primaryFixtureName = 'Anti-Glare Daylight LED Panel (6500K)';
        extraFixtures.add({
          'name': 'Dedicated Desk Task / Monitor Backlight Strip',
          'watts': 15,
          'va': 18.0,
          'citation': 'IESNA RP-1 Office Lighting',
        });
        break;

      case RoomType.garageStorage:
        // Garage/Outdoor: Wide flood/bulkhead or batten
        lampWatts = 18;
        lumensPerLamp = 1600;
        fixtures = (safeArea / 12.0).ceil().clamp(1, 4);
        primaryFixtureName = 'Weatherproof IP65 LED Batten / Bulkhead';
        break;

      case RoomType.classroom:
      case RoomType.laboratory:
        // Classroom & Labs: High lumen 2x4 LED Troffers (36W/40W, 3600-4000 lumens)
        lampWatts = 36;
        lumensPerLamp = 3800;
        // Standard classroom (40-50 sqm) typically needs 6 to 8 troffers for 400 Lux
        fixtures = (totalTargetLumens / lumensPerLamp).round().clamp(2, 12);
        primaryFixtureName = '2x4 Recessed LED Troffer (4000K Neutral White)';
        extraFixtures.add({
          'name': 'Whiteboard / Teacher Podium Asymmetric Task Floodlight',
          'watts': 24,
          'va': 30.0,
          'citation': 'DOLE Rule 1075 / IESNA RP-3 Classroom Standard',
        });
        break;

      case RoomType.workshop:
        // Industrial Workshop / Welding Area: High-Bay IP65 or High-Output LED Battens (500 Lux)
        lampWatts = 60;
        lumensPerLamp = 6500;
        fixtures = (totalTargetLumens / lumensPerLamp).round().clamp(2, 8);
        primaryFixtureName = 'Industrial High-Bay IP65 LED Luminaire (5000K)';
        extraFixtures.add({
          'name': 'Dedicated Machine Bench Tool Task Light',
          'watts': 30,
          'va': 38.0,
          'citation': 'PEC Art 4.10 / DOLE Rule 1075 Workshop Standard',
        });
        break;

      case RoomType.facultyOffice:
        // Faculty & Admin: Low-glare 2x2 or 2x4 LED panels (350 Lux)
        lampWatts = 28;
        lumensPerLamp = 3000;
        fixtures = (totalTargetLumens / lumensPerLamp).round().clamp(2, 12);
        primaryFixtureName = 'Low-Glare UGR<19 LED Panel (4000K)';
        break;

      case RoomType.commercialRetail:
        // Retail: High illuminance (500 Lux) + Track Spotlights
        lampWatts = 20;
        lumensPerLamp = 2200;
        fixtures = (totalTargetLumens / lumensPerLamp).round().clamp(4, 16);
        primaryFixtureName = 'Commercial High-CRI LED Recessed Downlight';
        extraFixtures.add({
          'name': 'Magnetic Accent Track Spotlight System (Display Shelves)',
          'watts': 40,
          'va': 50.0,
          'citation': 'IESNA RP-2 Retail Lighting Standards',
        });
        break;

      case RoomType.commercialRestaurant:
        // Restaurant / Dining: Warm atmospheric (200 Lux)
        lampWatts = 10;
        lumensPerLamp = 900;
        fixtures = (totalTargetLumens / lumensPerLamp).round().clamp(4, 12);
        primaryFixtureName = 'Warm Dimmable LED Downlight (2700K)';
        break;

      case RoomType.hallwayCorridor:
        // Hallway & Corridors (100 Lux)
        lampWatts = 12;
        lumensPerLamp = 1100;
        fixtures = (safeArea / 8.0).ceil().clamp(1, 8);
        primaryFixtureName = 'Wide-Beam LED Corridor Ceiling Luminaire';
        break;
    }

    // Add Architectural Tiers if requested
    if (tier == LightingTier.premium) {
      final coveWatts = (safeArea * 3.0).clamp(20.0, 80.0);
      extraFixtures.add({
        'name': 'Architectural LED Cove / Accent Strip (Warm White 3000K)',
        'watts': coveWatts.round(),
        'va': coveWatts / 0.85,
        'citation': 'PEC Art 4.10 / IESNA Layered Illuminance',
      });
    } else if (tier == LightingTier.luxury) {
      final coveWatts = (safeArea * 4.0).clamp(30.0, 100.0);
      extraFixtures.add({
        'name': 'Perimeter Architectural LED Cove Strip (Dimmable Tri-Color)',
        'watts': coveWatts.round(),
        'va': coveWatts / 0.85,
        'citation': 'PEC Art 4.10.12 (Concealed Luminaires)',
      });
      final trackSpots = (safeArea / 6.0).ceil().clamp(2, 6);
      extraFixtures.add({
        'name': 'Magnetic Track / Gimbal Accent Spotlights ($trackSpots pcs)',
        'watts': trackSpots * 10,
        'va': (trackSpots * 10) / 0.85,
        'citation': 'PEC Art 4.10.14 (Track Lighting)',
      });
    }

    // Compute Total Connected VA (Primary + Extras)
    final double primaryVA = fixtures * (lampWatts / 0.85);
    final double extraVA = extraFixtures.fold(0.0, (sum, f) => sum + (f['va'] as num).toDouble());
    double totalVA = primaryVA + extraVA;

    // PEC Section 2.20.2.3 Check (24 VA/m² minimum design floor)
    final double pecMinGeneralLightingVA = safeArea * 24.0;
    if (totalVA < pecMinGeneralLightingVA) {
      totalVA = pecMinGeneralLightingVA;
    }

    final extraNote = extraFixtures.isNotEmpty ? ' May ${extraFixtures.length} karagdagang specialty/task fixtures.' : '';
    final explanation =
        'Batay sa ${tier.label} para sa ${roomType.label} ($lux Lux benchmark, ${safeArea.toStringAsFixed(1)} m²): '
        'Inirerekomenda ang $fixtures pcs $lampWatts W $primaryFixtureName ($lumensPerLamp lm bawat isa).$extraNote';

    return LightingRecommendation(
      roomType: roomType,
      tier: tier,
      roomAreaSqm: safeArea,
      targetLumens: totalTargetLumens,
      primaryFixtureName: primaryFixtureName,
      recommendedWattagePerFixture: lampWatts,
      lumensPerFixture: lumensPerLamp,
      fixtureCount: fixtures,
      totalLightingVA: totalVA,
      explanation: explanation,
      extraFixtures: extraFixtures,
    );
  }
}
