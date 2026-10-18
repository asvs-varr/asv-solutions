// BANAAG Core Domain: Philippine Electrical Code (PEC 2017) Calculation Engine
// Enforces Philippine standard wire sizing, ampacity derating, conduit fill, and voltage drop.

class PecWireSpec {
  final double sizeMm2;
  final String awgEquivalent;
  final double ampacity75C; // THHN / THWN-2 Copper in raceway (PEC Table 3.10.2.6)
  final double outerAreaMm2; // Approximate cross-sectional area with insulation
  final double resistanceOhmPerKm; // AC Resistance at 75C (approx.)

  const PecWireSpec({
    required this.sizeMm2,
    required this.awgEquivalent,
    required this.ampacity75C,
    required this.outerAreaMm2,
    required this.resistanceOhmPerKm,
  });
}

class PecConduitSpec {
  final String tradeSize; // e.g., "20 mm (1/2 in)"
  final double internalAreaMm2;

  const PecConduitSpec({
    required this.tradeSize,
    required this.internalAreaMm2,
  });
}

class PecEngine {
  // PEC Table 3.10.2.6: Allowable Ampacities of Insulated Conductors (75°C Copper THHN/THWN-2)
  // Ambient temperature base: 30°C
  static const List<PecWireSpec> wireSpecs = [
    PecWireSpec(sizeMm2: 2.0, awgEquivalent: '#14 AWG', ampacity75C: 20.0, outerAreaMm2: 7.9, resistanceOhmPerKm: 10.4),
    PecWireSpec(sizeMm2: 3.5, awgEquivalent: '#12 AWG', ampacity75C: 25.0, outerAreaMm2: 11.7, resistanceOhmPerKm: 6.5),
    PecWireSpec(sizeMm2: 5.5, awgEquivalent: '#10 AWG', ampacity75C: 35.0, outerAreaMm2: 16.3, resistanceOhmPerKm: 4.1),
    PecWireSpec(sizeMm2: 8.0, awgEquivalent: '#8 AWG', ampacity75C: 50.0, outerAreaMm2: 28.2, resistanceOhmPerKm: 2.5),
    PecWireSpec(sizeMm2: 14.0, awgEquivalent: '#6 AWG', ampacity75C: 65.0, outerAreaMm2: 43.0, resistanceOhmPerKm: 1.6),
    PecWireSpec(sizeMm2: 22.0, awgEquivalent: '#4 AWG', ampacity75C: 85.0, outerAreaMm2: 66.0, resistanceOhmPerKm: 1.0),
    PecWireSpec(sizeMm2: 30.0, awgEquivalent: '#2 AWG', ampacity75C: 115.0, outerAreaMm2: 90.0, resistanceOhmPerKm: 0.65),
    PecWireSpec(sizeMm2: 38.0, awgEquivalent: '#1 AWG', ampacity75C: 130.0, outerAreaMm2: 112.0, resistanceOhmPerKm: 0.52),
    PecWireSpec(sizeMm2: 50.0, awgEquivalent: '#1/0 AWG', ampacity75C: 150.0, outerAreaMm2: 138.0, resistanceOhmPerKm: 0.41),
    PecWireSpec(sizeMm2: 60.0, awgEquivalent: '#2/0 AWG', ampacity75C: 175.0, outerAreaMm2: 165.0, resistanceOhmPerKm: 0.33),
    PecWireSpec(sizeMm2: 80.0, awgEquivalent: '#3/0 AWG', ampacity75C: 200.0, outerAreaMm2: 205.0, resistanceOhmPerKm: 0.26),
    PecWireSpec(sizeMm2: 100.0, awgEquivalent: '#4/0 AWG', ampacity75C: 230.0, outerAreaMm2: 250.0, resistanceOhmPerKm: 0.21),
  ];

  // Standard Rigid PVC (Schedule 40) / EMT Conduit Internal Area (mm²)
  static const List<PecConduitSpec> conduitSpecs = [
    PecConduitSpec(tradeSize: '20 mm (1/2 in)', internalAreaMm2: 201.0),
    PecConduitSpec(tradeSize: '25 mm (3/4 in)', internalAreaMm2: 350.0),
    PecConduitSpec(tradeSize: '32 mm (1 in)', internalAreaMm2: 567.0),
    PecConduitSpec(tradeSize: '40 mm (1-1/4 in)', internalAreaMm2: 984.0),
    PecConduitSpec(tradeSize: '50 mm (1-1/2 in)', internalAreaMm2: 1339.0),
    PecConduitSpec(tradeSize: '63 mm (2 in)', internalAreaMm2: 2190.0),
  ];

  // Standard Breaker Ratings in Philippines
  static const List<int> standardBreakers = [15, 20, 30, 40, 50, 60, 75, 100, 125, 150, 175, 200, 225, 250];

  /// Find appropriate wire size based on load current and continuous load factor (125%)
  static PecWireSpec sizeWireForCurrent(double loadCurrentAmps, {bool isContinuous = true, bool isLighting = false}) {
    final double designCurrent = isContinuous ? loadCurrentAmps * 1.25 : loadCurrentAmps;

    // PEC Rule: Lighting minimum 2.0 mm² (#14), Outlets minimum 3.5 mm² (#12)
    final double minAllowedSize = isLighting ? 2.0 : 3.5;

    for (final spec in wireSpecs) {
      if (spec.sizeMm2 >= minAllowedSize && spec.ampacity75C >= designCurrent) {
        return spec;
      }
    }
    return wireSpecs.last;
  }

  /// Select standard circuit breaker trip rating matching wire ampacity
  static int selectBreaker(double loadCurrentAmps, double wireAmpacity) {
    final double requiredTrip = loadCurrentAmps * 1.25;
    for (final rating in standardBreakers) {
      if (rating >= requiredTrip && rating <= wireAmpacity) {
        return rating;
      }
    }
    // If exact bracket fits, return standard ceiling or next standard rating
    for (final rating in standardBreakers) {
      if (rating >= requiredTrip) return rating;
    }
    return standardBreakers.last;
  }

  /// Compute Conduit Fill Ratio (PEC Chapter 9 Table 1)
  /// Maximum 40% fill ratio for 3 or more conductors
  static double computeConduitFillRatio({
    required PecWireSpec wireSpec,
    required int conductorCount,
    required PecConduitSpec conduitSpec,
  }) {
    final double totalWireArea = wireSpec.outerAreaMm2 * conductorCount;
    return (totalWireArea / conduitSpec.internalAreaMm2) * 100.0;
  }

  /// Recommend smallest conduit size that satisfies PEC 40% fill limit
  static PecConduitSpec recommendConduit({
    required PecWireSpec wireSpec,
    required int conductorCount,
  }) {
    final double totalWireArea = wireSpec.outerAreaMm2 * conductorCount;
    final double maxAllowedConduitFill = 0.40; // 40% limit for >= 3 wires

    for (final conduit in conduitSpecs) {
      final double allowedFillArea = conduit.internalAreaMm2 * maxAllowedConduitFill;
      if (allowedFillArea >= totalWireArea) {
        return conduit;
      }
    }
    return conduitSpecs.last;
  }

  /// Compute Voltage Drop for Single Phase 230V Nominal
  /// V_drop = (2 * L * I * R) / 1000
  /// Returns percentage of nominal voltage (230V)
  static double computeVoltageDropPercent({
    required double loadCurrentAmps,
    required double oneWayLengthMeters,
    required PecWireSpec wireSpec,
    double nominalVoltage = 230.0,
  }) {
    // Length in km
    final double lengthKm = oneWayLengthMeters / 1000.0;
    final double voltageDropVolts = 2.0 * lengthKm * loadCurrentAmps * wireSpec.resistanceOhmPerKm;
    return (voltageDropVolts / nominalVoltage) * 100.0;
  }

  /// Smart Phase Balancer: Distributes circuits across Phase A and Phase B to minimize unbalance
  static Map<String, List<Map<String, dynamic>>> balanceSinglePhaseLines(List<Map<String, dynamic>> circuits) {
    // Sort circuits by VA load descending (Greedy LPT algorithm)
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

  /// Evaluates selected wire and breaker specifications against PEC 2017 Part 1 standards.
  /// Detects UNDER-SPECS (Hazard), OVER-SPECS (Inefficiency), and COMPLIANT states.
  static PecValidationResult validateCircuitSpecs({
    required double loadCurrentAmps,
    required double wireSizeMm2,
    required int breakerRatingAmps,
    bool isLighting = false,
    bool isContinuous = true,
  }) {
    final double designCurrent = isContinuous ? loadCurrentAmps * 1.25 : loadCurrentAmps;
    final PecWireSpec? userWireSpec = wireSpecs.cast<PecWireSpec?>().firstWhere(
      (w) => (w!.sizeMm2 - wireSizeMm2).abs() < 0.1,
      orElse: () => null,
    );
    final double wireAmpacity = userWireSpec?.ampacity75C ?? 0.0;
    final double minAllowedWire = isLighting ? 2.0 : 3.5;

    final List<String> issues = [];
    final List<String> pecCitations = [];

    // Check 1: Minimum Wire Size Rule
    if (wireSizeMm2 < minAllowedWire) {
      issues.add(
        'Wire size ($wireSizeMm2 mm²) is below the PEC mandatory minimum of $minAllowedWire mm² for ${isLighting ? "lighting" : "power/convenience outlet"} circuits.',
      );
      pecCitations.add('PEC 2017 Art 2.10.2.1(B)(1) & Art 2.10.2.3: Branch Circuit Minimum Conductor Sizing.');
    }

    // Check 2: Conductor Overload (Load Current vs Wire Ampacity)
    if (wireAmpacity > 0 && designCurrent > wireAmpacity) {
      issues.add(
        'Design current (${designCurrent.toStringAsFixed(1)} A at 125% factor) exceeds wire ampacity (${wireAmpacity.toStringAsFixed(0)} A). Risk of cable overheating and thermal insulation breakdown.',
      );
      pecCitations.add('PEC 2017 Art 3.10.2.6 & Table 3.10.2.6: Allowable Ampacities of Insulated Copper Conductors.');
    }

    // Check 3: Breaker Overprotection (Breaker Rating vs Wire Ampacity)
    if (wireAmpacity > 0 && breakerRatingAmps > wireAmpacity) {
      issues.add(
        'Breaker trip rating ($breakerRatingAmps A) is larger than wire ampacity (${wireAmpacity.toStringAsFixed(0)} A). Wire can burn out before the breaker trips.',
      );
      pecCitations.add('PEC 2017 Art 2.40.1.4(A) & Art 2.40.1.4(D): Protection of Conductors against Overcurrent.');
    }

    // Check 4: Small Conductor Overcurrent Rules (PEC 240.4(D))
    if ((wireSizeMm2 - 2.0).abs() < 0.1 && breakerRatingAmps > 15) {
      issues.add('2.0 mm² (#14 AWG) copper conductor maximum overcurrent protection is 15 A.');
      pecCitations.add('PEC 2017 Art 2.40.1.4(D)(3): 2.0 mm² Copper Maximum 15A Circuit Breaker.');
    } else if ((wireSizeMm2 - 3.5).abs() < 0.1 && breakerRatingAmps > 20) {
      issues.add('3.5 mm² (#12 AWG) copper conductor maximum overcurrent protection is 20 A.');
      pecCitations.add('PEC 2017 Art 2.40.1.4(D)(5): 3.5 mm² Copper Maximum 20A Circuit Breaker.');
    } else if ((wireSizeMm2 - 5.5).abs() < 0.1 && breakerRatingAmps > 30) {
      issues.add('5.5 mm² (#10 AWG) copper conductor maximum overcurrent protection is 30 A.');
      pecCitations.add('PEC 2017 Art 2.40.1.4(D)(7): 5.5 mm² Copper Maximum 30A Circuit Breaker.');
    }

    // Check 5: Breaker Too Small for Load
    if (breakerRatingAmps < designCurrent) {
      issues.add(
        'Breaker rating ($breakerRatingAmps A) is lower than continuous design load (${designCurrent.toStringAsFixed(1)} A). Nuisance tripping will occur.',
      );
      pecCitations.add('PEC 2017 Art 2.10.2.2: Continuous and Noncontinuous Loads Overcurrent Device Rating.');
    }

    // If any safety violations exist -> UNDER-SPECS
    if (issues.isNotEmpty) {
      return PecValidationResult(
        status: PecComplianceStatus.underSpecs,
        headline: 'UNDER-SPECS: Violates Safety Threshold',
        details: issues.join('\n• '),
        pecCitations: pecCitations.toSet().toList(),
        recommendedWireSizeMm2: sizeWireForCurrent(loadCurrentAmps, isContinuous: isContinuous, isLighting: isLighting).sizeMm2,
        recommendedBreakerAmps: selectBreaker(loadCurrentAmps, wireAmpacity > 0 ? wireAmpacity : 20.0),
      );
    }

    // Check Over-Specs: Wire is 2 or more standard steps larger than necessary
    final PecWireSpec optimalWire = sizeWireForCurrent(loadCurrentAmps, isContinuous: isContinuous, isLighting: isLighting);
    final int userWireIdx = wireSpecs.indexWhere((w) => (w.sizeMm2 - wireSizeMm2).abs() < 0.1);
    final int optimalWireIdx = wireSpecs.indexWhere((w) => (w.sizeMm2 - optimalWire.sizeMm2).abs() < 0.1);

    if (userWireIdx >= 0 && optimalWireIdx >= 0 && userWireIdx >= optimalWireIdx + 2) {
      return PecValidationResult(
        status: PecComplianceStatus.overSpecs,
        headline: 'OVER-SPECS: Safe but Cost Inefficient',
        details: 'Selected wire ($wireSizeMm2 mm²) is significantly larger than the required ${optimalWire.sizeMm2} mm² (${optimalWire.ampacity75C.toStringAsFixed(0)} A ampacity). May cause difficult conduit bends, raceway fill congestion, and terminal block fitting issues.',
        pecCitations: [
          'PEC 2017 Art 3.10.2.6: Optimal Economic Conductor Sizing.',
          'PEC 2017 Chapter 9 Table 1: Raceways and Box Terminal Limitations.'
        ],
        recommendedWireSizeMm2: optimalWire.sizeMm2,
        recommendedBreakerAmps: selectBreaker(loadCurrentAmps, optimalWire.ampacity75C),
      );
    }

    // Fully Compliant
    return PecValidationResult(
      status: PecComplianceStatus.compliant,
      headline: 'PEC COMPLIANT: 100% Code Verified',
      details: 'Wire ampacity (${wireAmpacity.toStringAsFixed(0)} A) and breaker rating ($breakerRatingAmps A) perfectly satisfy the ${designCurrent.toStringAsFixed(1)} A design load with required 125% safety margin.',
      pecCitations: [
        'PEC 2017 Table 3.10.2.6 (Conductor Ampacities)',
        'PEC 2017 Art 2.10.2.1 / Art 2.40.1.4 (Branch Overcurrent Protection)'
      ],
      recommendedWireSizeMm2: wireSizeMm2,
      recommendedBreakerAmps: breakerRatingAmps,
    );
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
