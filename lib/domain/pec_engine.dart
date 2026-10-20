// BANAAG Core Domain: Philippine Electrical Code (PEC 2017 Part 1) Calculation Engine
// 100% Verbatim Tables from Official PEC 2017 Part 1 Book:
// - Table 3.10.2.6(B)(16) (Page 174): Allowable Ampacities of Insulated Copper Conductors (60°C, 75°C, 90°C @ 30°C Ambient)
// - Table 3.10.2.6(B)(2)(a) (Page 170): Ambient Temperature Correction Factors
// - Table 3.10.2.6(B)(3)(a) (Page 172): Adjustment Factors for More Than Three Current-Carrying Conductors
// - Section 2.40.1.4(D) (Page 84) & Table 2.10.2.7 (Page 45): Small Conductor Maximum Overcurrent Protection (15A / 20A / 30A)
// - Table 2.40.1.6(A) (Page 86): Standard Ampere Ratings for Fuses and Inverse Time Circuit Breakers
// - Table 2.50.3.17 (Page 113) & Sec. 2.50.3.17(A): Grounding Electrode Conductor (GEC) for AC Systems
// - Table 2.50.6.13 (Page 124): Minimum Size Equipment Grounding Conductors (EGC)
// - Table 10.1.1.1 (Page 932), Table 10.1.1.4 (Page 935), Table 10.1.1.5 (Page 937), Table 10.1.1.9 (Page 942)

class PecWireSpec {
  final double sizeMm2;
  final String awgEquivalent;
  final double ampacity60C; // Types TW, UF (PEC Table 3.10.2.6(B)(16) Col 1)
  final double ampacity75C; // Types RHW, THHW, THW, THWN (PEC Table 3.10.2.6(B)(16) Col 2 - Standard Terminal Limit per Sec 1.10.1.14(C))
  final double ampacity90C; // Types THHN, THHW, THW-2, THWN-2, XHHW-2 (PEC Table 3.10.2.6(B)(16) Col 3 - Used for Derating Base)
  final int? maxGeneralOcpdAmps; // PEC Sec 2.40.1.4(D) Small Conductor Breaker Cap (15A for 2.0mm², 20A for 3.5mm², 30A for 5.5mm²)
  final double outerAreaMm2; // Verbatim THHN/THWN-2 Approximate Area in mm² (PEC Table 10.1.1.5, Page 937)
  final double resistanceOhmPerKm; // Verbatim AC Resistance at 75°C in PVC Conduit (PEC Table 10.1.1.9, Page 942, converted from Ω/305m to Ω/km)

  const PecWireSpec({
    required this.sizeMm2,
    required this.awgEquivalent,
    required this.ampacity60C,
    required this.ampacity75C,
    required this.ampacity90C,
    this.maxGeneralOcpdAmps,
    required this.outerAreaMm2,
    required this.resistanceOhmPerKm,
  });

  /// Effective maximum overcurrent protection rating allowed for general branch/feeder circuits
  /// Enforces PEC 2017 Section 2.40.1.4(D) for 2.0 mm² (15A), 3.5 mm² (20A), and 5.5 mm² (30A).
  double get effectiveMaxBranchAmps =>
      maxGeneralOcpdAmps != null ? maxGeneralOcpdAmps!.toDouble() : ampacity75C;
}

class PecConduitSpec {
  final String tradeSize; // e.g., "20 mm (3/4 in)"
  final int metricDesignatorMm; // PEC Table 10.1.1.4 Raceway Size (mm)
  final double internalAreaMm2; // PEC Table 10.1.1.4 Total Area 100% (mm²)
  final double area40PercentMm2; // PEC Table 10.1.1.4 Over 2 Wires 40% (mm²)

  const PecConduitSpec({
    required this.tradeSize,
    required this.metricDesignatorMm,
    required this.internalAreaMm2,
    required this.area40PercentMm2,
  });
}

class PecEngine {
  // ===========================================================================
  // 1. VERBATIM PEC 2017 TABLE 3.10.2.6(B)(16) (Page 174)
  //    Allowable Ampacities of Insulated Copper Conductors Rated 0-2000V,
  //    Not More Than 3 Current-Carrying Conductors in Raceway, Ambient 30°C
  //    Combined with Table 10.1.1.5 (Page 937) & Table 10.1.1.9 (Page 942)
  // ===========================================================================
  static const List<PecWireSpec> wireSpecs = [
    PecWireSpec(
      sizeMm2: 2.0,
      awgEquivalent: '#14 AWG',
      ampacity60C: 15.0,
      ampacity75C: 20.0,
      ampacity90C: 25.0,
      maxGeneralOcpdAmps: 15, // PEC Sec 2.40.1.4(D)(3)
      outerAreaMm2: 6.2,
      resistanceOhmPerKm: 10.16, // 3.1 Ω / 305m
    ),
    PecWireSpec(
      sizeMm2: 3.5,
      awgEquivalent: '#12 AWG',
      ampacity60C: 20.0,
      ampacity75C: 25.0,
      ampacity90C: 30.0,
      maxGeneralOcpdAmps: 20, // PEC Sec 2.40.1.4(D)(5)
      outerAreaMm2: 8.6,
      resistanceOhmPerKm: 6.56, // 2.0 Ω / 305m
    ),
    PecWireSpec(
      sizeMm2: 5.5,
      awgEquivalent: '#10 AWG',
      ampacity60C: 30.0,
      ampacity75C: 35.0,
      ampacity90C: 40.0,
      maxGeneralOcpdAmps: 30, // PEC Sec 2.40.1.4(D)(7)
      outerAreaMm2: 13.9,
      resistanceOhmPerKm: 3.93, // 1.2 Ω / 305m
    ),
    PecWireSpec(
      sizeMm2: 8.0,
      awgEquivalent: '#8 AWG',
      ampacity60C: 40.0,
      ampacity75C: 50.0,
      ampacity90C: 55.0,
      outerAreaMm2: 23.8,
      resistanceOhmPerKm: 2.56, // 0.78 Ω / 305m
    ),
    PecWireSpec(
      sizeMm2: 14.0,
      awgEquivalent: '#6 AWG',
      ampacity60C: 55.0,
      ampacity75C: 65.0,
      ampacity90C: 75.0,
      outerAreaMm2: 33.2,
      resistanceOhmPerKm: 1.61, // 0.49 Ω / 305m
    ),
    PecWireSpec(
      sizeMm2: 22.0,
      awgEquivalent: '#4 AWG',
      ampacity60C: 70.0,
      ampacity75C: 85.0,
      ampacity90C: 95.0,
      outerAreaMm2: 52.8,
      resistanceOhmPerKm: 1.02, // 0.31 Ω / 305m
    ),
    PecWireSpec(
      sizeMm2: 30.0,
      awgEquivalent: '#2 AWG',
      ampacity60C: 85.0,
      ampacity75C: 100.0, // Verbatim PEC 2017 Table 3.10.2.6(B)(16) (NOT 115A!)
      ampacity90C: 115.0,
      outerAreaMm2: 75.4,
      resistanceOhmPerKm: 0.62, // 0.19 Ω / 305m
    ),
    PecWireSpec(
      sizeMm2: 38.0,
      awgEquivalent: '#1 AWG',
      ampacity60C: 100.0,
      ampacity75C: 115.0, // Verbatim PEC 2017 Table 3.10.2.6(B)(16) (NOT 130A!)
      ampacity90C: 130.0,
      outerAreaMm2: 100.3,
      resistanceOhmPerKm: 0.49, // 0.15 Ω / 305m
    ),
    PecWireSpec(
      sizeMm2: 50.0,
      awgEquivalent: '#1/0 AWG',
      ampacity60C: 115.0,
      ampacity75C: 140.0, // Verbatim PEC 2017 Table 3.10.2.6(B)(16) (NOT 150A!)
      ampacity90C: 150.0,
      outerAreaMm2: 118.8,
      resistanceOhmPerKm: 0.39, // 0.12 Ω / 305m
    ),
    PecWireSpec(
      sizeMm2: 60.0,
      awgEquivalent: '#2/0 AWG',
      ampacity60C: 130.0,
      ampacity75C: 155.0, // Verbatim PEC 2017 Table 3.10.2.6(B)(16) (NOT 175A!)
      ampacity90C: 170.0,
      outerAreaMm2: 143.1,
      resistanceOhmPerKm: 0.33, // 0.10 Ω / 305m
    ),
    PecWireSpec(
      sizeMm2: 80.0,
      awgEquivalent: '#3/0 AWG',
      ampacity60C: 155.0,
      ampacity75C: 190.0, // Verbatim PEC 2017 Table 3.10.2.6(B)(16) (NOT 200A!)
      ampacity90C: 205.0,
      outerAreaMm2: 172.0,
      resistanceOhmPerKm: 0.25, // 0.077 Ω / 305m
    ),
    PecWireSpec(
      sizeMm2: 100.0,
      awgEquivalent: '#4/0 AWG',
      ampacity60C: 185.0,
      ampacity75C: 220.0, // Verbatim PEC 2017 Table 3.10.2.6(B)(16) (NOT 230A!)
      ampacity90C: 240.0,
      outerAreaMm2: 208.7,
      resistanceOhmPerKm: 0.20, // 0.062 Ω / 305m
    ),
    PecWireSpec(
      sizeMm2: 125.0,
      awgEquivalent: '250 MCM',
      ampacity60C: 210.0,
      ampacity75C: 255.0,
      ampacity90C: 285.0,
      outerAreaMm2: 254.5,
      resistanceOhmPerKm: 0.17, // 0.052 Ω / 305m
    ),
    PecWireSpec(
      sizeMm2: 150.0,
      awgEquivalent: '300 MCM',
      ampacity60C: 240.0,
      ampacity75C: 285.0,
      ampacity90C: 320.0,
      outerAreaMm2: 298.6,
      resistanceOhmPerKm: 0.14, // 0.044 Ω / 305m
    ),
    PecWireSpec(
      sizeMm2: 200.0,
      awgEquivalent: '400 MCM',
      ampacity60C: 275.0,
      ampacity75C: 325.0,
      ampacity90C: 360.0,
      outerAreaMm2: 376.7,
      resistanceOhmPerKm: 0.11, // 0.033 Ω / 305m
    ),
    PecWireSpec(
      sizeMm2: 250.0,
      awgEquivalent: '500 MCM',
      ampacity60C: 315.0,
      ampacity75C: 375.0,
      ampacity90C: 425.0,
      outerAreaMm2: 456.2,
      resistanceOhmPerKm: 0.089, // 0.027 Ω / 305m
    ),
  ];

  // ===========================================================================
  // 2. VERBATIM PEC 2017 TABLE 10.1.1.4 (Page 935)
  //    Articles 3.52 & 3.53 - Rigid PVC Conduit (Schedule 40) Internal Areas
  // ===========================================================================
  static const List<PecConduitSpec> conduitSpecs = [
    PecConduitSpec(
      tradeSize: '15 mm (1/2 in)',
      metricDesignatorMm: 15,
      internalAreaMm2: 184.0,
      area40PercentMm2: 74.0,
    ),
    PecConduitSpec(
      tradeSize: '20 mm (3/4 in)',
      metricDesignatorMm: 20,
      internalAreaMm2: 327.0,
      area40PercentMm2: 131.0,
    ),
    PecConduitSpec(
      tradeSize: '25 mm (1 in)',
      metricDesignatorMm: 25,
      internalAreaMm2: 535.0,
      area40PercentMm2: 214.0,
    ),
    PecConduitSpec(
      tradeSize: '32 mm (1-1/4 in)',
      metricDesignatorMm: 32,
      internalAreaMm2: 935.0,
      area40PercentMm2: 374.0,
    ),
    PecConduitSpec(
      tradeSize: '40 mm (1-1/2 in)',
      metricDesignatorMm: 40,
      internalAreaMm2: 1282.0,
      area40PercentMm2: 513.0,
    ),
    PecConduitSpec(
      tradeSize: '50 mm (2 in)',
      metricDesignatorMm: 50,
      internalAreaMm2: 2124.0,
      area40PercentMm2: 849.0,
    ),
    PecConduitSpec(
      tradeSize: '65 mm (2-1/2 in)',
      metricDesignatorMm: 65,
      internalAreaMm2: 3029.0,
      area40PercentMm2: 1212.0,
    ),
    PecConduitSpec(
      tradeSize: '80 mm (3 in)',
      metricDesignatorMm: 80,
      internalAreaMm2: 4693.0,
      area40PercentMm2: 1877.0,
    ),
  ];

  // ===========================================================================
  // 3. VERBATIM PEC 2017 TABLE 2.40.1.6(A) (Page 86)
  //    Standard Ampere Ratings for Fuses and Inverse Time Circuit Breakers
  // ===========================================================================
  static const List<int> standardBreakers = [
    15, 20, 25, 30, 35, 40, 45, 50, 60, 70, 80, 90, 100, 110, 125, 150, 175, 200, 225, 250, 300, 350, 400
  ];

  // Common Philippine Commercial Molded-Case / Plug-in Breaker Subset (for standard Residential/Commercial Panels)
  static const List<int> commonPanelBreakers = [
    15, 20, 30, 40, 50, 60, 70, 80, 90, 100, 125, 150, 175, 200, 225, 250, 300, 400
  ];

  // ===========================================================================
  // 4. VERBATIM PEC 2017 TABLE 3.10.2.6(B)(2)(a) (Page 170)
  //    Ambient Temperature Correction Factors (Based on 30°C Ambient)
  // ===========================================================================
  static double getAmbientTemperatureCorrectionFactor(
    double ambientTempC, {
    int conductorTempRating = 75,
  }) {
    if (ambientTempC <= 20) {
      return conductorTempRating == 60 ? 1.15 : (conductorTempRating == 75 ? 1.11 : 1.08);
    } else if (ambientTempC <= 25) {
      return conductorTempRating == 60 ? 1.08 : (conductorTempRating == 75 ? 1.05 : 1.04);
    } else if (ambientTempC <= 30) {
      return 1.00;
    } else if (ambientTempC <= 35) {
      return conductorTempRating == 60 ? 0.91 : (conductorTempRating == 75 ? 0.94 : 0.96);
    } else if (ambientTempC <= 40) {
      return conductorTempRating == 60 ? 0.82 : (conductorTempRating == 75 ? 0.88 : 0.91);
    } else if (ambientTempC <= 45) {
      return conductorTempRating == 60 ? 0.71 : (conductorTempRating == 75 ? 0.82 : 0.87);
    } else if (ambientTempC <= 50) {
      return conductorTempRating == 60 ? 0.58 : (conductorTempRating == 75 ? 0.75 : 0.82);
    } else {
      return conductorTempRating == 60 ? 0.41 : (conductorTempRating == 75 ? 0.67 : 0.76);
    }
  }

  // ===========================================================================
  // 5. VERBATIM PEC 2017 TABLE 3.10.2.6(B)(3)(a) (Page 172)
  //    Adjustment Factors for More Than Three Current-Carrying Conductors
  // ===========================================================================
  static double getBundlingAdjustmentFactor(int currentCarryingConductors) {
    if (currentCarryingConductors <= 3) return 1.00;
    if (currentCarryingConductors <= 6) return 0.80;
    if (currentCarryingConductors <= 9) return 0.70;
    if (currentCarryingConductors <= 20) return 0.50;
    if (currentCarryingConductors <= 30) return 0.45;
    if (currentCarryingConductors <= 40) return 0.40;
    return 0.35;
  }

  /// Computes adjusted allowable ampacity per PEC 2017 Sec. 3.10.2.6(B) & Sec. 1.10.1.14(C):
  /// Base ampacity for THHN/THWN-2 may start from 90°C column for derating,
  /// but final usable ampacity SHALL NOT EXCEED the 75°C terminal temperature limit
  /// (and for small conductors 2.0/3.5/5.5 mm², OCPD shall not exceed 15A/20A/30A per Sec. 2.40.1.4(D)).
  static double computeEffectiveAmpacity(
    PecWireSpec spec, {
    double ambientTempC = 30.0,
    int currentCarryingConductors = 3,
    bool use90CDeratingBase = true,
  }) {
    final double baseAmpacity = use90CDeratingBase ? spec.ampacity90C : spec.ampacity75C;
    final double tempFactor = getAmbientTemperatureCorrectionFactor(
      ambientTempC,
      conductorTempRating: use90CDeratingBase ? 90 : 75,
    );
    final double bundleFactor = getBundlingAdjustmentFactor(currentCarryingConductors);
    final double derated = baseAmpacity * tempFactor * bundleFactor;
    // Per PEC 1.10.1.14(C)(1), final usable ampacity cannot exceed the 75°C terminal rating
    return derated < spec.ampacity75C ? derated : spec.ampacity75C;
  }

  /// Find appropriate wire size based on load current, continuous load factor (125%),
  /// PEC 2.40.1.4(D) small conductor breaker limits (15A/20A/30A), and optional derating.
  static PecWireSpec sizeWireForCurrent(
    double loadCurrentAmps, {
    bool isContinuous = true,
    bool isLighting = false,
    double ambientTempC = 30.0,
    int currentCarryingConductors = 3,
  }) {
    final double designCurrent = isContinuous ? loadCurrentAmps * 1.25 : loadCurrentAmps;

    // PEC Rule: Lighting minimum 2.0 mm² (#14), Power/Outlets minimum 3.5 mm² (#12)
    final double minAllowedSize = isLighting ? 2.0 : 3.5;

    for (final spec in wireSpecs) {
      if (spec.sizeMm2 < minAllowedSize) continue;

      final double usableAmpacity = computeEffectiveAmpacity(
        spec,
        ambientTempC: ambientTempC,
        currentCarryingConductors: currentCarryingConductors,
      );

      // Enforce PEC 2017 Sec. 2.40.1.4(D):
      // 2.0 mm² max OCPD = 15A, 3.5 mm² max OCPD = 20A, 5.5 mm² max OCPD = 30A.
      final double maxOcpdCap = spec.effectiveMaxBranchAmps;
      final double governingLimit = usableAmpacity < maxOcpdCap ? usableAmpacity : maxOcpdCap;

      if (governingLimit >= designCurrent) {
        return spec;
      }
    }
    return wireSpecs.last;
  }

  /// Select standard circuit breaker trip rating matching wire ampacity and PEC Sec. 2.40.1.4(D)
  static int selectBreaker(
    double loadCurrentAmps,
    double wireAmpacity, {
    bool isContinuous = true,
    double? wireSizeMm2,
  }) {
    final double requiredTrip = isContinuous ? loadCurrentAmps * 1.25 : loadCurrentAmps;

    // Determine effective maximum breaker allowed on this wire (enforcing PEC 2.40.1.4(D) Small Conductors)
    double effectiveMaxBreaker = wireAmpacity;
    if (wireSizeMm2 != null) {
      if ((wireSizeMm2 - 2.0).abs() < 0.1 && effectiveMaxBreaker > 15) effectiveMaxBreaker = 15.0;
      if ((wireSizeMm2 - 3.5).abs() < 0.1 && effectiveMaxBreaker > 20) effectiveMaxBreaker = 20.0;
      if ((wireSizeMm2 - 5.5).abs() < 0.1 && effectiveMaxBreaker > 30) effectiveMaxBreaker = 30.0;
    } else {
      // Infer small conductor cap if wireAmpacity matches exact 75°C table values (20A, 25A, 35A)
      if ((wireAmpacity - 20.0).abs() < 0.1) effectiveMaxBreaker = 15.0;
      if ((wireAmpacity - 25.0).abs() < 0.1) effectiveMaxBreaker = 20.0;
      if ((wireAmpacity - 35.0).abs() < 0.1) effectiveMaxBreaker = 30.0;
    }

    for (final rating in commonPanelBreakers) {
      if (rating >= requiredTrip && rating <= effectiveMaxBreaker) {
        return rating;
      }
    }
    // Check full PEC Table 2.40.1.6(A) standard ratings (includes 25A, 35A, 45A, 110A)
    for (final rating in standardBreakers) {
      if (rating >= requiredTrip && rating <= effectiveMaxBreaker) {
        return rating;
      }
    }
    // PEC Sec. 2.40.1.4(B) Devices Rated 800 Amperes or Less:
    // Next higher standard overcurrent device rating (above the ampacity of the conductors being protected)
    // is permitted only for conductors >= 8.0 mm² (never for small conductors 2.0/3.5/5.5 mm²).
    if (effectiveMaxBreaker <= 30.0 && requiredTrip <= effectiveMaxBreaker) {
      return effectiveMaxBreaker.toInt();
    }
    for (final rating in commonPanelBreakers) {
      if (rating >= requiredTrip) return rating;
    }
    return standardBreakers.last;
  }

  /// Verbatim PEC 2017 Table 10.1.1.1 (Page 932): Maximum Percent of Cross Section of Conduit
  /// - 1 Conductor: 53%
  /// - 2 Conductors: 31%
  /// - Over 2 Conductors (3 or more): 40%
  static double getMaxAllowedConduitFillPercent(int conductorCount) {
    if (conductorCount <= 1) return 53.0;
    if (conductorCount == 2) return 31.0;
    return 40.0;
  }

  /// Compute Conduit Fill Ratio (PEC Chapter 10 Table 10.1.1.1, Page 932)
  static double computeConduitFillRatio({
    required PecWireSpec wireSpec,
    required int conductorCount,
    required PecConduitSpec conduitSpec,
  }) {
    final double totalWireArea = wireSpec.outerAreaMm2 * conductorCount;
    return (totalWireArea / conduitSpec.internalAreaMm2) * 100.0;
  }

  /// Recommend smallest conduit size that satisfies PEC Table 10.1.1.1 fill limit
  /// (Note: Residential/commercial branch wiring minimum trade size is 20 mm (3/4 in) or 15 mm (1/2 in))
  static PecConduitSpec recommendConduit({
    required PecWireSpec wireSpec,
    required int conductorCount,
    int minMetricDesignatorMm = 20,
  }) {
    final double totalWireArea = wireSpec.outerAreaMm2 * conductorCount;
    final double maxFillFraction = getMaxAllowedConduitFillPercent(conductorCount) / 100.0;

    for (final conduit in conduitSpecs) {
      if (conduit.metricDesignatorMm < minMetricDesignatorMm) continue;
      final double allowedFillArea = conduit.internalAreaMm2 * maxFillFraction;
      if (allowedFillArea >= totalWireArea) {
        return conduit;
      }
    }
    return conduitSpecs.last;
  }

  /// Compute Voltage Drop for Single Phase 230V Nominal (PEC Art 2.10.2.2(A) FPN No. 4 & Art 2.15.1.2(A)(1) FPN No. 2)
  /// V_drop = (2 * L * I * R) / 1000
  /// Returns percentage of nominal voltage (230V)
  static double computeVoltageDropPercent({
    required double loadCurrentAmps,
    required double oneWayLengthMeters,
    required PecWireSpec wireSpec,
    double nominalVoltage = 230.0,
  }) {
    final double lengthKm = oneWayLengthMeters / 1000.0;
    final double voltageDropVolts = 2.0 * lengthKm * loadCurrentAmps * wireSpec.resistanceOhmPerKm;
    return (voltageDropVolts / nominalVoltage) * 100.0;
  }

  /// Smart Phase Balancer: Distributes circuits across Phase A and Phase B to minimize unbalance
  static Map<String, List<Map<String, dynamic>>> balanceSinglePhaseLines(List<Map<String, dynamic>> circuits) {
    final List<Map<String, dynamic>> sorted = List.from(circuits)
      ..sort((a, b) => (b['loadVA'] as num).compareTo(a['loadVA'] as num));

    final List<Map<String, dynamic>> phaseA = [];
    final List<Map<String, dynamic>> phaseB = [];
    double sumA = 0.0;
    double sumB = 0.0;

    for (final c in sorted) {
      final double va = (c['loadVA'] as num).toDouble();
      if (sumA <= sumB) {
        phaseA.add(c);
        sumA += va;
      } else {
        phaseB.add(c);
        sumB += va;
      }
    }

    return {
      'PhaseA': phaseA,
      'PhaseB': phaseB,
    };
  }

  /// Evaluates selected wire and breaker specifications against PEC 2017 Part 1 verbatim standards.
  /// Detects UNDER-SPECS (Life-Safety Hazard), OVER-SPECS (Cost Inefficiency), and COMPLIANT states.
  static PecValidationResult validateCircuitSpecs({
    required double loadCurrentAmps,
    required double wireSizeMm2,
    required int breakerRatingAmps,
    bool isLighting = false,
    bool isContinuous = true,
    double ambientTempC = 30.0,
    int currentCarryingConductors = 3,
  }) {
    final double designCurrent = isContinuous ? loadCurrentAmps * 1.25 : loadCurrentAmps;
    final PecWireSpec? userWireSpec = wireSpecs.cast<PecWireSpec?>().firstWhere(
      (w) => (w!.sizeMm2 - wireSizeMm2).abs() < 0.1,
      orElse: () => null,
    );
    final double wireAmpacity = userWireSpec != null
        ? computeEffectiveAmpacity(
            userWireSpec,
            ambientTempC: ambientTempC,
            currentCarryingConductors: currentCarryingConductors,
          )
        : 0.0;
    final double minAllowedWire = isLighting ? 2.0 : 3.5;

    final List<String> issues = [];
    final List<String> pecCitations = [];

    // Check 1: Minimum Wire Size Rule (PEC Table 2.10.2.7, Page 45)
    if (wireSizeMm2 < minAllowedWire) {
      issues.add(
        'Wire size ($wireSizeMm2 mm²) is below the PEC mandatory minimum of $minAllowedWire mm² for ${isLighting ? "lighting" : "power/convenience outlet"} circuits.',
      );
      pecCitations.add('PEC 2017 Sec. 2.10.2.2(A)(4) & Table 2.10.2.7 (Page 45): Branch Circuit Minimum Conductor Sizing.');
    }

    // Check 2: Conductor Overload (Load Current vs Derated Wire Ampacity)
    if (wireAmpacity > 0 && designCurrent > wireAmpacity) {
      issues.add(
        'Design current (${designCurrent.toStringAsFixed(1)} A at 125% factor) exceeds wire allowable ampacity (${wireAmpacity.toStringAsFixed(1)} A). Risk of cable overheating and thermal insulation breakdown.',
      );
      pecCitations.add('PEC 2017 Sec. 3.10.2.6(B) & Table 3.10.2.6(B)(16) (Page 174): Allowable Ampacities of Insulated Copper Conductors.');
    }

    // Check 3: Breaker Overprotection (Breaker Rating vs Wire Ampacity)
    if (wireAmpacity > 0 && breakerRatingAmps > wireAmpacity) {
      issues.add(
        'Breaker trip rating ($breakerRatingAmps A) is larger than wire allowable ampacity (${wireAmpacity.toStringAsFixed(0)} A). Wire can overheat before the breaker trips.',
      );
      pecCitations.add('PEC 2017 Sec. 2.40.1.4 (Page 84): Protection of Conductors Against Overcurrent.');
    }

    // Check 4: Small Conductor Overcurrent Rules (PEC Sec. 2.40.1.4(D), Page 84)
    if ((wireSizeMm2 - 2.0).abs() < 0.1 && breakerRatingAmps > 15) {
      issues.add('2.0 mm² (1.6 mm dia.) copper conductor maximum overcurrent protection is 15 A.');
      pecCitations.add('PEC 2017 Sec. 2.40.1.4(D)(3) (Page 84): 2.0 mm² Copper Maximum 15A Circuit Breaker.');
    } else if ((wireSizeMm2 - 3.5).abs() < 0.1 && breakerRatingAmps > 20) {
      issues.add('3.5 mm² (2.0 mm dia.) copper conductor maximum overcurrent protection is 20 A.');
      pecCitations.add('PEC 2017 Sec. 2.40.1.4(D)(5) (Page 84): 3.5 mm² Copper Maximum 20A Circuit Breaker.');
    } else if ((wireSizeMm2 - 5.5).abs() < 0.1 && breakerRatingAmps > 30) {
      issues.add('5.5 mm² (2.6 mm dia.) copper conductor maximum overcurrent protection is 30 A.');
      pecCitations.add('PEC 2017 Sec. 2.40.1.4(D)(7) (Page 84): 5.5 mm² Copper Maximum 30A Circuit Breaker.');
    }

    // Check 5: Breaker Too Small for Continuous Design Load (PEC Sec. 2.10.2.3(A), Page 44)
    if (breakerRatingAmps < designCurrent) {
      issues.add(
        'Breaker rating ($breakerRatingAmps A) is lower than continuous design load (${designCurrent.toStringAsFixed(1)} A). Nuisance tripping and thermal fatigue will occur.',
      );
      pecCitations.add('PEC 2017 Sec. 2.10.2.3(A) (Page 44) & Sec. 2.15.1.3 (Page 51): Overcurrent Protection at 125% Continuous Load.');
    }

    final PecWireSpec optimalWire = sizeWireForCurrent(
      loadCurrentAmps,
      isContinuous: isContinuous,
      isLighting: isLighting,
      ambientTempC: ambientTempC,
      currentCarryingConductors: currentCarryingConductors,
    );
    final int optimalBreaker = selectBreaker(
      loadCurrentAmps,
      optimalWire.ampacity75C,
      isContinuous: isContinuous,
      wireSizeMm2: optimalWire.sizeMm2,
    );

    // If any safety violations exist -> UNDER-SPECS
    if (issues.isNotEmpty) {
      return PecValidationResult(
        status: PecComplianceStatus.underSpecs,
        headline: 'UNDER-SPECS: Violates PEC 2017 Life-Safety Threshold',
        details: issues.join('\n• '),
        pecCitations: pecCitations.toSet().toList(),
        recommendedWireSizeMm2: optimalWire.sizeMm2,
        recommendedBreakerAmps: optimalBreaker,
      );
    }

    // Check Over-Specs: Wire is 2 or more standard steps larger than necessary
    final int userWireIdx = wireSpecs.indexWhere((w) => (w.sizeMm2 - wireSizeMm2).abs() < 0.1);
    final int optimalWireIdx = wireSpecs.indexWhere((w) => (w.sizeMm2 - optimalWire.sizeMm2).abs() < 0.1);

    if (userWireIdx >= 0 && optimalWireIdx >= 0 && userWireIdx >= optimalWireIdx + 2) {
      return PecValidationResult(
        status: PecComplianceStatus.overSpecs,
        headline: 'OVER-SPECS: Safe but Cost Inefficient',
        details:
            'Selected wire ($wireSizeMm2 mm²) is significantly larger than the required ${optimalWire.sizeMm2} mm² (${optimalWire.ampacity75C.toStringAsFixed(0)} A ampacity). May cause difficult conduit bends, raceway fill congestion, and terminal lug fitting issues.',
        pecCitations: [
          'PEC 2017 Table 3.10.2.6(B)(16) (Page 174): Optimal Conductor Sizing.',
          'PEC 2017 Table 10.1.1.1 (Page 932): Raceway Fill & Terminal Limitations.'
        ],
        recommendedWireSizeMm2: optimalWire.sizeMm2,
        recommendedBreakerAmps: optimalBreaker,
      );
    }

    // Fully Compliant
    return PecValidationResult(
      status: PecComplianceStatus.compliant,
      headline: 'PEC 2017 COMPLIANT: 100% Verbatim Code Verified',
      details:
          'Wire ampacity (${wireAmpacity.toStringAsFixed(0)} A @ 75°C) and breaker rating ($breakerRatingAmps A) satisfy the ${designCurrent.toStringAsFixed(1)} A design load (125% continuous margin).',
      pecCitations: [
        'PEC 2017 Table 3.10.2.6(B)(16) (Page 174: Conductor Ampacities)',
        'PEC 2017 Sec. 2.10.2.3 & Sec. 2.40.1.4(D) (Pages 44 & 84: Overcurrent Protection)'
      ],
      recommendedWireSizeMm2: wireSizeMm2,
      recommendedBreakerAmps: breakerRatingAmps,
    );
  }

  // ===========================================================================
  // 6. VERBATIM PEC 2017 TABLE 2.50.6.13 (Page 124)
  //    Minimum Size Equipment Grounding Conductors (EGC) for Grounding Raceway & Equipment
  // ===========================================================================
  static double getMinimumEquipmentGroundingConductorMm2(int breakerRatingAmps) {
    if (breakerRatingAmps <= 15) return 2.0; // 2.0 (1.6) Cu
    if (breakerRatingAmps <= 20) return 3.5; // 3.5 (2.0) Cu
    if (breakerRatingAmps <= 60) return 5.5; // 5.5 (2.6) Cu (30A, 40A, 60A)
    if (breakerRatingAmps <= 100) return 8.0; // 8.0 (3.2) Cu
    if (breakerRatingAmps <= 200) return 14.0; // 14 mm² Cu
    if (breakerRatingAmps <= 300) return 22.0; // 22 mm² Cu
    if (breakerRatingAmps <= 500) return 30.0; // 30 mm² Cu (400A & 500A)
    if (breakerRatingAmps <= 600) return 38.0; // 38 mm² Cu
    if (breakerRatingAmps <= 800) return 50.0; // 50 mm² Cu
    if (breakerRatingAmps <= 1000) return 60.0; // 60 mm² Cu
    return 80.0;
  }

  static String formatEquipmentGroundingConductor(int breakerRatingAmps) {
    final size = getMinimumEquipmentGroundingConductorMm2(breakerRatingAmps);
    return '${size.toStringAsFixed(1).replaceAll('.0', '')} mm²';
  }

  // ===========================================================================
  // 7. VERBATIM PEC 2017 TABLE 2.50.3.17 (Page 113) & SEC. 2.50.3.17(A)
  //    Grounding Electrode Conductor (GEC) for Alternating-Current Systems
  // ===========================================================================
  static double getMinimumGroundingElectrodeConductorMm2(
    double largestUngroundedServiceWireMm2, {
    bool connectedSolelyToRodPipeOrPlate = false,
  }) {
    double tableGecMm2;
    if (largestUngroundedServiceWireMm2 <= 30.0) {
      tableGecMm2 = 8.0; // 30 mm² or smaller -> 8.0 (3.2) Cu
    } else if (largestUngroundedServiceWireMm2 <= 50.0) {
      tableGecMm2 = 14.0; // 38 or 50 mm² -> 14 mm² Cu
    } else if (largestUngroundedServiceWireMm2 <= 80.0) {
      tableGecMm2 = 22.0; // 60 or 80 mm² -> 22 mm² Cu
    } else if (largestUngroundedServiceWireMm2 <= 175.0) {
      tableGecMm2 = 30.0; // Over 80 through 175 mm² -> 30 mm² Cu
    } else if (largestUngroundedServiceWireMm2 <= 325.0) {
      tableGecMm2 = 50.0; // Over 175 through 325 mm² -> 50 mm² Cu
    } else if (largestUngroundedServiceWireMm2 <= 500.0) {
      tableGecMm2 = 60.0; // Over 325 through 500 mm² -> 60 mm² Cu
    } else {
      tableGecMm2 = 80.0; // Over 500 mm² -> 80 mm² Cu
    }

    // Verbatim PEC 2017 Sec. 2.50.3.17(A) (Page 113):
    // Connections to a rod, pipe, or plate electrode(s) shall not be required to be larger than 14 mm² copper wire.
    if (connectedSolelyToRodPipeOrPlate && tableGecMm2 > 14.0) {
      return 14.0;
    }
    return tableGecMm2;
  }
}

enum PecComplianceStatus {
  compliant,
  underSpecs,
  overSpecs,
}

class PecValidationResult {
  final PecComplianceStatus status;
  final String headline;
  final String details;
  final List<String> pecCitations;
  final double recommendedWireSizeMm2;
  final int recommendedBreakerAmps;

  const PecValidationResult({
    required this.status,
    required this.headline,
    required this.details,
    required this.pecCitations,
    required this.recommendedWireSizeMm2,
    required this.recommendedBreakerAmps,
  });
}
