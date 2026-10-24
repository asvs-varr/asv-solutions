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
  final double rcrValue;
  final double cuValue;
  final double llfValue;
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
    this.rcrValue = 2.5,
    this.cuValue = 0.65,
    this.llfValue = 0.80,
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

  /// Calculates recommended lighting fixtures using the authoritative IESNA Lighting Handbook 10th Edition:
  /// - Equation 10.32 (Page 10.34): Polygon Room Cavity Ratio RCR = 2.5 * h_RC * Perimeter / Area_net
  /// - Equation 10.31 (Page 10.33): Zonal-Cavity Lumen Method N = (E * A_net) / (Phi_lamp * CU(RCR) * LLF)
  static LightingRecommendation calculate({
    required RoomType roomType,
    required double areaSqm,
    double ceilingHeightMeters = 2.7,
    double? perimeterMeters,
    double? rcrOverride,
    LightingTier tier = LightingTier.standard,
  }) {
    final double safeArea = areaSqm <= 0 ? 12.0 : areaSqm;
    final int lux = roomType.recommendedLux;

    // Workplane cavity height h_RC = CeilingHeight - 0.80m workplane (IESNA 10th Ed. Ch. 10)
    final double hRc = (ceilingHeightMeters - 0.80).clamp(1.2, 8.0);
    final double estPerim = (perimeterMeters != null && perimeterMeters > 2.0)
        ? perimeterMeters
        : (4.2 * (safeArea > 0 ? safeArea : 12.0) / 3.5).clamp(8.0, 120.0);

    // IESNA 10th Edition Equation 10.32: RCR = 2.5 * h_RC * Perimeter / Area_net
    final double rcr = (rcrOverride != null && rcrOverride > 0.2)
        ? rcrOverride
        : ((2.5 * hRc * estPerim) / safeArea).clamp(0.6, 12.0);

    // Zonal-Cavity Coefficient of Utilization CU(RCR) for standard 80/50/20 ceiling/wall/floor reflectance
    final double cu = (0.78 / (1.0 + 0.11 * rcr)).clamp(0.34, 0.76);
    const double llf = 0.80; // Light Loss Factor (LLD * LDD)

    // IESNA 10th Edition Equation 10.31: Total Required Lamp Lumens = (E_maintained * Area_net * TierMultiplier) / (CU * LLF)
    final double totalTargetLumens = (safeArea * lux * tier.lumenMultiplier) / (cu * llf);

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

    final extraNote = extraFixtures.isNotEmpty ? ' Includes ${extraFixtures.length} additional specialty/task fixtures.' : '';
    final explanation =
        'IESNA 10th Ed. Eq. 10.31/10.32 (${roomType.label}, $lux Lux, Net Area ${safeArea.toStringAsFixed(1)} m², RCR=${rcr.toStringAsFixed(2)}, CU=${cu.toStringAsFixed(2)}, LLF=$llf): '
        'Recommended $fixtures pcs ${lampWatts}W $primaryFixtureName ($lumensPerLamp lm each).$extraNote';

    return LightingRecommendation(
      roomType: roomType,
      tier: tier,
      roomAreaSqm: safeArea,
      rcrValue: rcr,
      cuValue: cu,
      llfValue: llf,
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
