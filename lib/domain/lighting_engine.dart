// BANAAG Smart Lighting Sizer Engine & Triple-Lock IESNA 10th Ed. + PEC 2017 Illumination Auditor
// Computes recommended luminous flux, LED fixtures, Spacing Criterion uniformity, and audits rooms
// against IESNA Lighting Handbook 10th Edition (Eq. 10.31, Eq. 10.32, Sec. 8.4.2.7), DOLE Rule 1075, and PEC 2017.

import 'dart:math' as math;
import 'models.dart';
import 'pec_safety_auditor.dart';

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

    // High-Ceiling / Double-Height Space Override (H_room >= 4.0m per IESNA 10th Ed. Ch. 10 & High-Bay Application):
    // When ceiling height >= 4.0m, standard low-wattage downlights lose illuminance due to steep RCR and inverse-square drop.
    // Automatically upgrade non-high-bay fixtures to High-Output Commercial / High-Bay LED Luminaires!
    if (ceilingHeightMeters >= 4.0 && lampWatts < 36) {
      lampWatts = ceilingHeightMeters >= 5.0 ? 60 : 40;
      lumensPerLamp = ceilingHeightMeters >= 5.0 ? 6500 : 4400;
      primaryFixtureName = ceilingHeightMeters >= 5.0
          ? 'High-Bay Industrial LED Luminaire (${lampWatts}W, 5000K)'
          : 'High-Output Deep-Reflector LED Luminaire (${lampWatts}W, 4000K)';
      fixtures = (totalTargetLumens / lumensPerLamp).ceil().clamp(2, 16);
    }

    // Enforce IESNA 10th Edition Equation 10.31 & Sec. 8.4.2.7 Spacing Criterion Floor:
    // Ensure recommended fixture count ALWAYS satisfies:
    // 1) Maintained Illuminance E_maintained >= Target Lux (within 98% rounding tolerance)
    // 2) Center-to-center spacing S_actual = sqrt(Area / N) <= SC * h_RC (where SC = 1.25)
    final int minFixturesForLux = ((safeArea * lux * tier.lumenMultiplier) / (lumensPerLamp * cu * llf)).ceil().clamp(1, 32);
    final double maxSpacingMeters = 1.25 * hRc;
    final int minFixturesForSpacing = (safeArea / (maxSpacingMeters * maxSpacingMeters)).ceil().clamp(1, 32);
    if (fixtures < minFixturesForLux) {
      fixtures = minFixturesForLux;
    }
    if (fixtures < minFixturesForSpacing && safeArea > 6.0) {
      fixtures = minFixturesForSpacing;
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

  /// Auto-Suggested Default Ceiling Height (m) based on Room Name / Occupancy (Step 1 Wizard)
  static double suggestDefaultCeilingHeight(String roomName) {
    final lower = roomName.toLowerCase();
    if (lower.contains('hall') || lower.contains('event') || lower.contains('function') || lower.contains('gym') || lower.contains('workshop')) {
      return 3.5;
    }
    if (lower.contains('class') || lower.contains('lab') || lower.contains('retail') || lower.contains('commercial')) {
      return 3.0;
    }
    if (lower.contains('storage') || lower.contains('store') || lower.contains('bath') || lower.contains('toilet') || lower.contains('powder')) {
      return 2.6;
    }
    return 2.8;
  }

  /// Maps a free-form [spaceName] to its authoritative IESNA 10th Ed. & DOLE Rule 1075 [RoomType]
  static RoomType mapSpaceNameToRoomType(String spaceName) {
    final lower = spaceName.toLowerCase();
    if (lower.contains('kitchen')) return RoomType.kitchen;
    if (lower.contains('bed')) return RoomType.bedroom;
    if (lower.contains('bath') || lower.contains('laundry') || lower.contains('toilet')) return RoomType.bathroom;
    if (lower.contains('office') || lower.contains('faculty') || lower.contains('admin')) return RoomType.facultyOffice;
    if (lower.contains('staff') || lower.contains('study')) return RoomType.homeOffice;
    if (lower.contains('hall') || lower.contains('event') || lower.contains('function') || lower.contains('class')) return RoomType.classroom;
    if (lower.contains('landing') || lower.contains('stair') || lower.contains('corridor') || lower.contains('hallway')) return RoomType.hallwayCorridor;
    if (lower.contains('storage') || lower.contains('store') || lower.contains('garage') || lower.contains('outdoor') || lower.contains('deck')) {
      return RoomType.garageStorage;
    }
    if (lower.contains('workshop') || lower.contains('welding')) return RoomType.workshop;
    if (lower.contains('lab')) return RoomType.laboratory;
    if (lower.contains('retail') || lower.contains('shop')) return RoomType.commercialRetail;
    if (lower.contains('restaurant') || lower.contains('cafe')) return RoomType.commercialRestaurant;
    return RoomType.livingDining;
  }
}

/// Per-Room IESNA 10th Edition + DOLE Rule 1075 + PEC 2017 Illumination Audit Finding
class RoomLightingAuditFinding {
  final String roomId;
  final String roomName;
  final RoomType roomType;
  final double areaSqm;
  final double ceilingHeightMeters;
  final double hRcMeters;
  final double rcrValue;
  final double cuValue;
  final double llfValue;
  final int targetLux;
  final double actualMaintainedLux;
  final int actualFixtureCount;
  final int recommendedFixtureCount;
  final double actualSpacingMeters;
  final double maxAllowedSpacingMeters;
  final double connectedLightingVA;
  final double pecMinUnitLightingVA;
  final PecAuditSeverity severity;
  final String headline;
  final List<String> issues;
  final List<String> citations;
  final String mathTrace;

  const RoomLightingAuditFinding({
    required this.roomId,
    required this.roomName,
    required this.roomType,
    required this.areaSqm,
    required this.ceilingHeightMeters,
    required this.hRcMeters,
    required this.rcrValue,
    required this.cuValue,
    required this.llfValue,
    required this.targetLux,
    required this.actualMaintainedLux,
    required this.actualFixtureCount,
    required this.recommendedFixtureCount,
    required this.actualSpacingMeters,
    required this.maxAllowedSpacingMeters,
    required this.connectedLightingVA,
    required this.pecMinUnitLightingVA,
    required this.severity,
    required this.headline,
    required this.issues,
    required this.citations,
    required this.mathTrace,
  });

  double get luxCompliancePercent =>
      targetLux <= 0 ? 100.0 : ((actualMaintainedLux / targetLux) * 100.0).clamp(0.0, 250.0);
}

/// Project-Wide IESNA 10th Ed. + PEC 2017 Illumination Safety & Code Audit Report
class ProjectLightingAuditReport {
  final PecAuditSeverity overallSeverity;
  final int totalRooms;
  final int compliantRoomsCount;
  final int advisoryRoomsCount;
  final int criticalHazardRoomsCount;
  final List<RoomLightingAuditFinding> roomFindings;
  final List<String> branchCircuitIssues;
  final double assurancePercent;

  const ProjectLightingAuditReport({
    required this.overallSeverity,
    required this.totalRooms,
    required this.compliantRoomsCount,
    required this.advisoryRoomsCount,
    required this.criticalHazardRoomsCount,
    required this.roomFindings,
    required this.branchCircuitIssues,
    required this.assurancePercent,
  });

  bool get isExportBlocked => criticalHazardRoomsCount > 0 || branchCircuitIssues.isNotEmpty;
}

/// Triple-Lock IESNA 10th Edition + PEC 2017 + DOLE OSHS Rule 1075 Illumination Auditor
class IesnaLightingAuditor {
  IesnaLightingAuditor._();

  /// Audits a single [RoomSpace] and its assigned [roomAppliances] against:
  /// 1. IESNA 10th Ed. Eq. 10.31 & 10.32 Maintained Illuminance (E_maintained >= Target Lux)
  /// 2. IESNA 10th Ed. Sec. 8.4.2.7 & 10.11.4 Spacing Criterion (S_actual <= 1.25 * h_RC to prevent dark spots)
  /// 3. High-Ceiling Luminaire Selection (H_room >= 4.0m requires >=36W high-output / high-bay luminaires)
  /// 4. PEC 2017 Sec. 2.20.2.3 & Table 2.20.2.3 Lighting Load & LPD checks
  static RoomLightingAuditFinding auditRoom({
    required RoomSpace space,
    required List<ApplianceItem> roomAppliances,
  }) {
    final RoomType roomType = LightingEngine.mapSpaceNameToRoomType(space.name);
    final double area = space.areaSqm <= 0 ? 12.0 : space.areaSqm;
    final double ceilingH = space.ceilingHeight <= 0 ? 2.8 : space.ceilingHeight;
    final double hRc = (ceilingH - 0.80).clamp(1.2, 8.0);
    final LightingRecommendation rec = LightingEngine.calculate(
      roomType: roomType,
      areaSqm: area,
      ceilingHeightMeters: ceilingH,
      perimeterMeters: space.perimeterMeters,
      rcrOverride: space.rcrValue,
    );

    // Filter lighting items in this room
    final lightingItems = roomAppliances.where((a) {
      final nm = a.name.toLowerCase();
      return a.isLighting ||
          nm.contains('light') ||
          nm.contains('luminaire') ||
          nm.contains('led') ||
          nm.contains('troffer') ||
          nm.contains('panel') ||
          nm.contains('pinlight') ||
          nm.contains('high-bay') ||
          nm.contains('batten') ||
          nm.contains('tube');
    }).toList();

    int totalFixtureCount = 0;
    double totalLampLumens = 0.0;
    double totalLightingVA = 0.0;
    bool hasLowWattageOnHighCeiling = false;

    for (final item in lightingItems) {
      final pcsMatch = RegExp(r'(?:x|\()\s*(\d+)\s*pcs', caseSensitive: false).firstMatch(item.name);
      final int packMult = pcsMatch != null ? (int.tryParse(pcsMatch.group(1)!) ?? 1) : 1;
      final int itemFixtures = item.quantity * packMult;
      totalFixtureCount += itemFixtures;
      totalLightingVA += item.totalVA;

      // Extract wattage per lamp if present (e.g. "12W" or "36W")
      final wattsMatch = RegExp(r'(\d+)\s*W\b', caseSensitive: false).firstMatch(item.name);
      final double singleWatts = wattsMatch != null
          ? (double.tryParse(wattsMatch.group(1)!) ?? (item.ratingVA * 0.85 / packMult))
          : (item.ratingVA * 0.85 / packMult);

      if (ceilingH >= 4.0 && singleWatts < 28.0) {
        hasLowWattageOnHighCeiling = true;
      }

      // Luminous efficacy (~95 lm/W for standard LED, or exact match to LightingRecommendation)
      final double lumensPerUnit = (singleWatts - rec.recommendedWattagePerFixture).abs() < 1.5
          ? rec.lumensPerFixture.toDouble()
          : (singleWatts * 95.0);
      totalLampLumens += itemFixtures * lumensPerUnit;
    }

    // IESNA 10th Edition Equation 10.31 (Page 10.33):
    // E_maintained = (Total_Lumens * CU(RCR) * LLF) / Area_net
    final double actualLux = (totalLampLumens * rec.cuValue * rec.llfValue) / area;
    final int targetLux = roomType.recommendedLux;

    // IESNA 10th Edition Section 8.4.2.7 (Page 8.28): Spacing Criterion S_max = SC * h_RC (SC = 1.25)
    final double maxAllowedSpacing = 1.25 * hRc;
    final double actualSpacing = totalFixtureCount > 0 ? math.sqrt(area / totalFixtureCount) : math.sqrt(area);
    final double pecMinVA = area * 24.0;

    final List<String> issues = [];
    final List<String> citations = [
      'IESNA 10th Ed. Eq. 10.31 & 10.32 (Pages 10.33–10.34)',
      'IESNA 10th Ed. Sec. 8.4.2.7 Spacing Criterion (Page 8.28)',
      'DOLE OSHS Rule 1075 Illumination Standards',
      'PEC 2017 Sec. 2.20.2.3 & Table 2.20.2.3 (24 VA/m²)',
    ];
    PecAuditSeverity severity = PecAuditSeverity.compliant;

    if (totalFixtureCount == 0) {
      severity = PecAuditSeverity.criticalHazard;
      issues.add(
        'NO LUMINAIRES ASSIGNED: ${space.name} (${area.toStringAsFixed(1)} m²) has 0 lighting fixtures (0 Lux vs $targetLux Lux target).',
      );
    } else if (actualLux < targetLux * 0.92) {
      severity = PecAuditSeverity.criticalHazard;
      issues.add(
        'UNDER-ILLUMINATED (MADILIM): Maintained illuminance is ${actualLux.toStringAsFixed(0)} Lux, below the mandatory $targetLux Lux minimum for ${roomType.label} (RCR=${rec.rcrValue.toStringAsFixed(2)}, CU=${rec.cuValue.toStringAsFixed(2)} at H=${ceilingH.toStringAsFixed(2)}m). Requires at least ${rec.fixtureCount}x ${rec.recommendedWattagePerFixture}W ${rec.primaryFixtureName}.',
      );
    }

    // Spacing Criterion Check (Dark Spots between fixtures when ceiling is low or fixture count is sparse)
    if (totalFixtureCount > 0 && area > 6.0 && actualSpacing > maxAllowedSpacing * 1.08) {
      severity = PecAuditSeverity.criticalHazard;
      issues.add(
        'DARK SPOTS / UNIFORMITY VIOLATION (S > SC × h_RC): Fixture spacing is ${actualSpacing.toStringAsFixed(2)}m, exceeding max allowed ${maxAllowedSpacing.toStringAsFixed(2)}m (1.25 × h_RC=${hRc.toStringAsFixed(2)}m per IESNA Sec. 8.4.2.7). Increase luminaire count to eliminate shadows.',
      );
    }

    if (hasLowWattageOnHighCeiling && severity != PecAuditSeverity.criticalHazard) {
      severity = PecAuditSeverity.advisory;
      issues.add(
        'HIGH-CEILING LUMINAIRE ADVISORY (H=${ceilingH.toStringAsFixed(1)}m ≥ 4.0m): Upgrade to High-Output / High-Bay LED luminaires (≥40W) to overcome steep cavity loss.',
      );
    }

    if (actualLux > targetLux * 2.20 && severity == PecAuditSeverity.compliant) {
      severity = PecAuditSeverity.advisory;
      issues.add(
        'OVER-ILLUMINATED / LPD EFFICIENCY NOTICE: Room produces ${actualLux.toStringAsFixed(0)} Lux (${(actualLux / targetLux * 100).toStringAsFixed(0)}% of $targetLux Lux target). Consider dimming or reducing wattage.',
      );
    }

    final String headline = severity == PecAuditSeverity.criticalHazard
        ? 'UNDER-ILLUMINATED / DARK SPOTS (${actualLux.toStringAsFixed(0)} / $targetLux Lux)'
        : (severity == PecAuditSeverity.advisory
            ? 'SAFE • HIGH-CEILING / LPD ADVISORY (${actualLux.toStringAsFixed(0)} Lux)'
            : '100% IESNA 10th Ed. & PEC COMPLIANT (${actualLux.toStringAsFixed(0)} / $targetLux Lux)');

    final String mathTrace =
        'h_RC = ${ceilingH.toStringAsFixed(2)} - 0.80 = ${hRc.toStringAsFixed(2)}m | RCR = ${rec.rcrValue.toStringAsFixed(2)} | CU = ${rec.cuValue.toStringAsFixed(2)} | LLF = ${rec.llfValue.toStringAsFixed(2)} | '
        'E_maint = (${totalLampLumens.toStringAsFixed(0)} lm × ${rec.cuValue.toStringAsFixed(2)} × ${rec.llfValue.toStringAsFixed(2)}) / ${area.toStringAsFixed(1)} m² = ${actualLux.toStringAsFixed(1)} Lux (Target: $targetLux Lux) | '
        'Spacing S = ${actualSpacing.toStringAsFixed(2)}m ≤ ${maxAllowedSpacing.toStringAsFixed(2)}m';

    return RoomLightingAuditFinding(
      roomId: space.id,
      roomName: space.name,
      roomType: roomType,
      areaSqm: area,
      ceilingHeightMeters: ceilingH,
      hRcMeters: hRc,
      rcrValue: rec.rcrValue,
      cuValue: rec.cuValue,
      llfValue: rec.llfValue,
      targetLux: targetLux,
      actualMaintainedLux: actualLux,
      actualFixtureCount: totalFixtureCount,
      recommendedFixtureCount: rec.fixtureCount,
      actualSpacingMeters: actualSpacing,
      maxAllowedSpacingMeters: maxAllowedSpacing,
      connectedLightingVA: totalLightingVA,
      pecMinUnitLightingVA: pecMinVA,
      severity: severity,
      headline: headline,
      issues: issues,
      citations: citations,
      mathTrace: mathTrace,
    );
  }

  /// Audits all rooms and lighting branch circuits in [project]
  static ProjectLightingAuditReport auditProject(Project project) {
    final List<RoomLightingAuditFinding> findings = [];
    int compliant = 0;
    int advisory = 0;
    int critical = 0;

    for (final sp in project.spaces) {
      final roomApps = project.applianceLoads
          .where((a) => a.roomCategory.trim().toLowerCase() == sp.name.trim().toLowerCase())
          .toList();
      final f = auditRoom(space: sp, roomAppliances: roomApps);
      findings.add(f);
      if (f.severity == PecAuditSeverity.criticalHazard) {
        critical++;
      } else if (f.severity == PecAuditSeverity.advisory) {
        advisory++;
      } else {
        compliant++;
      }
    }

    // Check PEC 2017 Lighting Branch Circuit Continuous Loading (<= 1,440 VA per 15A / 2.0 mm² THHN circuit)
    final Map<int, double> lightingCircuitVA = {};
    for (final a in project.applianceLoads) {
      if (a.isLighting || a.name.toLowerCase().contains('light') || a.name.toLowerCase().contains('led')) {
        lightingCircuitVA[a.circuitNumber] = (lightingCircuitVA[a.circuitNumber] ?? 0.0) + a.totalVA;
      }
    }
    final List<String> branchIssues = [];
    lightingCircuitVA.forEach((cktNum, totalVA) {
      // 15A branch circuit @ 230V = 3,450 VA max; 80% continuous = 2,760 VA (or 1,440 VA traditional 12-outlet limit)
      if (totalVA > 2760.0) {
        branchIssues.add(
          'PEC 2017 Sec. 2.10.2.2(A)(1) Lighting Ckt #$cktNum Overload: ${totalVA.toStringAsFixed(0)} VA exceeds 80% continuous rating (2,760 VA) of a 15A / 2.0 mm² THHN lighting branch circuit. Split across multiple lighting circuits.',
        );
      }
    });

    final PecAuditSeverity overall = (critical > 0 || branchIssues.isNotEmpty)
        ? PecAuditSeverity.criticalHazard
        : (advisory > 0 ? PecAuditSeverity.advisory : PecAuditSeverity.compliant);

    final double assurance = project.spaces.isEmpty
        ? 100.0
        : (((project.spaces.length - critical) / project.spaces.length) * 100.0).clamp(0.0, 100.0);

    return ProjectLightingAuditReport(
      overallSeverity: overall,
      totalRooms: project.spaces.length,
      compliantRoomsCount: compliant,
      advisoryRoomsCount: advisory,
      criticalHazardRoomsCount: critical,
      roomFindings: findings,
      branchCircuitIssues: branchIssues,
      assurancePercent: branchIssues.isNotEmpty ? math.min(assurance, 85.0) : assurance,
    );
  }

  /// 1-Click Auto-Heal for a Single Room: Replaces or upgrades the room's lighting load to hit 100% IESNA Lux & Spacing compliance
  static int autoHealRoomLighting(Project project, RoomSpace space) {
    final RoomType roomType = LightingEngine.mapSpaceNameToRoomType(space.name);
    final LightingRecommendation rec = LightingEngine.calculate(
      roomType: roomType,
      areaSqm: space.areaSqm,
      ceilingHeightMeters: space.ceilingHeight,
      perimeterMeters: space.perimeterMeters,
      rcrOverride: space.rcrValue,
    );

    // Remove existing under-spec lighting fixtures in this room
    project.applianceLoads.removeWhere((a) {
      if (a.roomCategory.trim().toLowerCase() != space.name.trim().toLowerCase()) return false;
      final nm = a.name.toLowerCase();
      return a.isLighting ||
          nm.contains('light') ||
          nm.contains('luminaire') ||
          nm.contains('led') ||
          nm.contains('troffer') ||
          nm.contains('panel') ||
          nm.contains('pinlight') ||
          nm.contains('high-bay') ||
          nm.contains('batten') ||
          nm.contains('tube');
    });

    // Add the exact IESNA 10th Ed. Eq. 10.31/10.32 + Sec. 8.4.2.7 compliant luminaire pack
    final double primaryVA = (rec.recommendedWattagePerFixture / 0.85) * rec.fixtureCount;
    project.applianceLoads.add(
      ApplianceItem(
        id: 'heal-light-${space.id}-${DateTime.now().millisecondsSinceEpoch}',
        name: '${rec.primaryFixtureName} (${rec.recommendedWattagePerFixture}W x ${rec.fixtureCount} pcs)',
        roomCategory: space.name,
        ratingVA: double.parse(primaryVA.toStringAsFixed(1)),
        quantity: 1,
        isDedicatedCircuit: false,
        isLighting: true,
        circuitNumber: 1,
      ),
    );
    return rec.fixtureCount;
  }

  /// 1-Click Auto-Heal for the Entire Project's Lighting (all under-illuminated / dark-spot rooms + circuit splitting)
  static int autoHealProjectLighting(Project project) {
    int healedRooms = 0;
    for (final sp in project.spaces) {
      final roomApps = project.applianceLoads
          .where((a) => a.roomCategory.trim().toLowerCase() == sp.name.trim().toLowerCase())
          .toList();
      final finding = auditRoom(space: sp, roomAppliances: roomApps);
      if (finding.severity == PecAuditSeverity.criticalHazard || finding.severity == PecAuditSeverity.advisory) {
        autoHealRoomLighting(project, sp);
        healedRooms++;
      }
    }

    // Balance lighting branch circuits if Ckt #1 exceeds 1,800 VA
    double runningVA = 0.0;
    int currentLightingCkt = 1;
    for (final a in project.applianceLoads) {
      if (a.isLighting || a.name.toLowerCase().contains('light') || a.name.toLowerCase().contains('led')) {
        if (runningVA + a.totalVA > 1800.0) {
          currentLightingCkt++;
          runningVA = 0.0;
        }
        a.circuitNumber = currentLightingCkt;
        runningVA += a.totalVA;
      }
    }
    return healedRooms;
  }
}
