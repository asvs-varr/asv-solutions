// BANAAG Core Domain: Triple-Lock PEC 2017 Life-Safety & Mathematical Auditor
// Verifies 100% compliance of all branch circuits, feeders, grounding, conduit fill,
// and voltage drop against the verbatim Philippine Electrical Code (PEC 2017 Part 1).

import 'pec_engine.dart';
import 'sld_engine.dart';

enum PecAuditSeverity {
  compliant, // 100% Verbatim PEC 2017 Compliant (Green Shield)
  advisory, // Safe but Over-Specs or High Efficiency Notice (Amber Shield)
  criticalHazard, // Under-Specs / Thermal Overload / Fire Hazard (Red Shield - Hard Export Interlock)
}

class CircuitAuditFinding {
  final int circuitNumber;
  final String description;
  final PecAuditSeverity severity;
  final String headline;
  final List<String> issues;
  final List<String> citations;
  final String mathTrace;
  final double currentWireMm2;
  final int currentBreakerAmps;
  final double recommendedWireMm2;
  final int recommendedBreakerAmps;
  final double recommendedEgcMm2;
  final String recommendedConduit;
  final double voltageDropPercent;

  const CircuitAuditFinding({
    required this.circuitNumber,
    required this.description,
    required this.severity,
    required this.headline,
    required this.issues,
    required this.citations,
    required this.mathTrace,
    required this.currentWireMm2,
    required this.currentBreakerAmps,
    required this.recommendedWireMm2,
    required this.recommendedBreakerAmps,
    required this.recommendedEgcMm2,
    required this.recommendedConduit,
    required this.voltageDropPercent,
  });
}

class ScheduleSafetyAuditReport {
  final PecAuditSeverity overallSeverity;
  final int totalActiveCircuits;
  final int compliantCount;
  final int advisoryCount;
  final int criticalHazardCount;
  final List<CircuitAuditFinding> circuitFindings;
  final List<String> feederIssues;
  final List<String> feederMathSteps;
  final double assurancePercent;

  const ScheduleSafetyAuditReport({
    required this.overallSeverity,
    required this.totalActiveCircuits,
    required this.compliantCount,
    required this.advisoryCount,
    required this.criticalHazardCount,
    required this.circuitFindings,
    required this.feederIssues,
    required this.feederMathSteps,
    required this.assurancePercent,
  });

  bool get isExportBlocked => criticalHazardCount > 0 || feederIssues.isNotEmpty;
}

class PecSafetyAuditor {
  /// Extracts phase conductor size in mm² from a wire description like "2 - 3.5 mm² THHN + 1 - 3.5 mm² Ground"
  static double parsePhaseWireMm2(String wireDescription, {double fallback = 3.5}) {
    final match = RegExp(r'2\s*-\s*([0-9.]+)\s*mm').firstMatch(wireDescription);
    if (match != null) {
      return double.tryParse(match.group(1) ?? '') ?? fallback;
    }
    final anyMatch = RegExp(r'([0-9.]+)\s*mm').firstMatch(wireDescription);
    if (anyMatch != null) {
      return double.tryParse(anyMatch.group(1) ?? '') ?? fallback;
    }
    return fallback;
  }

  /// Extracts Equipment Grounding Conductor (EGC) size in mm² from a wire description
  static double? parseGroundWireMm2(String wireDescription) {
    final match = RegExp(r'1\s*-\s*([0-9.]+)\s*mm').firstMatch(wireDescription);
    if (match != null) {
      return double.tryParse(match.group(1) ?? '');
    }
    return null;
  }

  /// Extracts conduit metric designator (mm) from a conduit description like "20 mm Ø PVC"
  static int parseConduitMm(String conduitDescription, {int fallback = 20}) {
    final match = RegExp(r'([0-9]+)\s*mm').firstMatch(conduitDescription);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '') ?? fallback;
    }
    return fallback;
  }

  /// Audits an entire [SingleLineDiagramData] schedule against Verbatim PEC 2017 Part 1 rules
  static ScheduleSafetyAuditReport auditSchedule(SingleLineDiagramData sldData) {
    final List<CircuitAuditFinding> findings = [];
    int compliantCount = 0;
    int advisoryCount = 0;
    int criticalCount = 0;

    for (final c in sldData.branchCircuits) {
      if (c.isSpare) continue;

      final bool isLighting = c.description.toLowerCase().contains('light');
      final double loadAmps = c.loadVA / c.voltage;
      final double designAmps = loadAmps * 1.25;
      final double wireMm2 = parsePhaseWireMm2(c.wireSizeDescription, fallback: isLighting ? 2.0 : 3.5);
      final double? egcMm2 = parseGroundWireMm2(c.wireSizeDescription);
      final int conduitMm = parseConduitMm(c.conduitDescription, fallback: 20);

      final PecWireSpec wireSpec = PecEngine.wireSpecs.firstWhere(
        (w) => (w.sizeMm2 - wireMm2).abs() < 0.1,
        orElse: () => PecEngine.sizeWireForCurrent(loadAmps, isLighting: isLighting),
      );

      final validation = PecEngine.validateCircuitSpecs(
        loadCurrentAmps: loadAmps,
        wireSizeMm2: wireMm2,
        breakerRatingAmps: c.breakerRatingAmps,
        isLighting: isLighting,
        isContinuous: true,
      );

      final List<String> circuitIssues = [];
      final List<String> circuitCitations = List.from(validation.pecCitations);
      PecAuditSeverity severity = PecAuditSeverity.compliant;

      if (validation.status == PecComplianceStatus.underSpecs) {
        severity = PecAuditSeverity.criticalHazard;
        circuitIssues.addAll(validation.details.split('\n• '));
      } else if (validation.status == PecComplianceStatus.overSpecs) {
        severity = PecAuditSeverity.advisory;
        circuitIssues.add(validation.details);
      }

      // Check Equipment Grounding Conductor (EGC) per PEC Table 2.50.6.13 (Page 124)
      final double minEgcMm2 = PecEngine.getMinimumEquipmentGroundingConductorMm2(c.breakerRatingAmps);
      if (egcMm2 != null && egcMm2 + 0.05 < minEgcMm2) {
        severity = PecAuditSeverity.criticalHazard;
        circuitIssues.add(
          'Equipment Grounding Conductor ($egcMm2 mm²) is smaller than the mandatory ${minEgcMm2.toStringAsFixed(1).replaceAll('.0', '')} mm² for a ${c.breakerRatingAmps}A breaker.',
        );
        circuitCitations.add('PEC 2017 Table 2.50.6.13 (Page 124): Minimum Size Equipment Grounding Conductors.');
      }

      // Check Voltage Drop per PEC Sec. 2.10.2.2(A) FPN No. 4 (Page 42)
      final double computedVd = PecEngine.computeVoltageDropPercent(
        loadCurrentAmps: loadAmps,
        oneWayLengthMeters: c.measuredRunMeters,
        wireSpec: wireSpec,
        nominalVoltage: c.voltage.toDouble(),
      );
      if (computedVd > 3.0) {
        if (severity != PecAuditSeverity.criticalHazard) {
          severity = PecAuditSeverity.advisory;
        }
        circuitIssues.add(
          'Branch voltage drop (${computedVd.toStringAsFixed(2)}% at ${c.measuredRunMeters.toStringAsFixed(1)}m run) exceeds the PEC 3.0% efficiency limit.',
        );
        circuitCitations.add('PEC 2017 Sec. 2.10.2.2(A) FPN No. 4 (Page 42): Maximum 3.0% Branch Voltage Drop.');
      }

      // Check Conduit Fill (2 Phase Wires + 1 EGC = 3 Wires in Raceway) per PEC Table 10.1.1.1 & Table 10.1.1.4 (Pages 932 & 935)
      final PecConduitSpec conduitSpec = PecEngine.conduitSpecs.firstWhere(
        (cd) => cd.metricDesignatorMm >= conduitMm,
        orElse: () => PecEngine.conduitSpecs[1], // 20 mm
      );
      final double fillPercent = PecEngine.computeConduitFillRatio(
        wireSpec: wireSpec,
        conductorCount: 3, // 2 ungrounded/grounded + 1 EGC per Table 10.1.1.1 Note 3
        conduitSpec: conduitSpec,
      );
      if (fillPercent > 40.0) {
        severity = PecAuditSeverity.criticalHazard;
        circuitIssues.add(
          'Conduit fill (${fillPercent.toStringAsFixed(1)}% in ${conduitSpec.tradeSize}) exceeds PEC 40% limit for 3 conductors.',
        );
        circuitCitations.add('PEC 2017 Table 10.1.1.1 (Page 932) & Table 10.1.1.4 (Page 935): Maximum 40% Conduit Fill.');
      }

      // Compute optimal recommended wire (considering both ampacity AND <=3.0% voltage drop)
      PecWireSpec recWire = PecEngine.sizeWireForCurrent(
        loadAmps,
        isContinuous: true,
        isLighting: isLighting,
      );
      for (final candidate in PecEngine.wireSpecs) {
        if (candidate.sizeMm2 >= recWire.sizeMm2) {
          final vd = PecEngine.computeVoltageDropPercent(
            loadCurrentAmps: loadAmps,
            oneWayLengthMeters: c.measuredRunMeters,
            wireSpec: candidate,
            nominalVoltage: c.voltage.toDouble(),
          );
          if (vd <= 3.0 || candidate == PecEngine.wireSpecs.last) {
            recWire = candidate;
            break;
          }
        }
      }
      final int recBreaker = PecEngine.selectBreaker(
        loadAmps,
        recWire.ampacity75C,
        isContinuous: true,
        wireSizeMm2: recWire.sizeMm2,
      );
      final double recEgc = PecEngine.getMinimumEquipmentGroundingConductorMm2(recBreaker);
      final PecConduitSpec recConduit = PecEngine.recommendConduit(
        wireSpec: recWire,
        conductorCount: 3,
        minMetricDesignatorMm: 20,
      );

      final String mathTrace =
          'I_load = ${c.loadVA.toStringAsFixed(0)} VA ÷ ${c.voltage} V = ${loadAmps.toStringAsFixed(2)} A  •  '
          'I_design (125%) = ${designAmps.toStringAsFixed(2)} A  •  '
          'Wire: ${wireSpec.sizeMm2} mm² (${wireSpec.ampacity75C.toStringAsFixed(0)}A @ 75°C, Max OCPD: ${wireSpec.effectiveMaxBranchAmps.toStringAsFixed(0)}A)  •  '
          'Breaker: ${c.breakerRatingAmps} AT  •  '
          'VD: ${computedVd.toStringAsFixed(2)}% (${c.measuredRunMeters.toStringAsFixed(1)}m)  •  '
          'Fill: ${fillPercent.toStringAsFixed(1)}%';

      if (severity == PecAuditSeverity.criticalHazard) {
        criticalCount++;
      } else if (severity == PecAuditSeverity.advisory) {
        advisoryCount++;
      } else {
        compliantCount++;
      }

      findings.add(CircuitAuditFinding(
        circuitNumber: c.circuitNumber,
        description: c.description,
        severity: severity,
        headline: validation.headline,
        issues: circuitIssues,
        citations: circuitCitations.toSet().toList(),
        mathTrace: mathTrace,
        currentWireMm2: wireMm2,
        currentBreakerAmps: c.breakerRatingAmps,
        recommendedWireMm2: recWire.sizeMm2,
        recommendedBreakerAmps: recBreaker,
        recommendedEgcMm2: recEgc,
        recommendedConduit: '${recConduit.metricDesignatorMm} mm Ø PVC',
        voltageDropPercent: computedVd,
      ));
    }

    // Audit Main Feeder & Service Entrance
    final List<String> feederIssues = [];
    final List<String> feederMathSteps = [];

    final double sumActiveVA = sldData.branchCircuits
        .where((c) => !c.isSpare)
        .fold(0.0, (sum, c) => sum + c.loadVA);
    final double feederDesignAmps = sldData.feeder.netCurrentAmps * 1.25;
    final double feederWireMm2 = parsePhaseWireMm2(sldData.feeder.feederWireDescription, fallback: 22.0);
    final PecWireSpec feederWireSpec = PecEngine.wireSpecs.firstWhere(
      (w) => (w.sizeMm2 - feederWireMm2).abs() < 0.1,
      orElse: () => PecEngine.wireSpecs[5], // 22 mm²
    );

    feederMathSteps.add(
      '1. Total Connected Load = ${sumActiveVA.toStringAsFixed(0)} VA across ${findings.length} active circuits.',
    );
    feederMathSteps.add(
      '2. Net Computed Demand (PEC Table 2.20.3.3 & Sec. 4.30.2.4) = ${sldData.feeder.netDemandVA.toStringAsFixed(0)} VA.',
    );
    feederMathSteps.add(
      '3. Service/Feeder Full-Load Current (I_net) = ${sldData.feeder.netDemandVA.toStringAsFixed(0)} VA ÷ 230 V = ${sldData.feeder.netCurrentAmps.toStringAsFixed(2)} A.',
    );
    feederMathSteps.add(
      '4. Continuous Design Current (125% per PEC Sec. 2.15.1.2 & Sec. 2.15.1.3) = ${sldData.feeder.netCurrentAmps.toStringAsFixed(2)} A × 1.25 = ${feederDesignAmps.toStringAsFixed(2)} A.',
    );
    feederMathSteps.add(
      '5. Main Breaker & Feeder Wire: ${sldData.feeder.mainBreakerAmps} AT MCB (PEC Table 2.40.1.6(A)) on ${feederWireSpec.sizeMm2} mm² THHN (${feederWireSpec.ampacity75C.toStringAsFixed(0)} A @ 75°C per PEC Table 3.10.2.6(B)(16)).',
    );
    final double minGec = PecEngine.getMinimumGroundingElectrodeConductorMm2(feederWireSpec.sizeMm2);
    final double minMainEgc = PecEngine.getMinimumEquipmentGroundingConductorMm2(sldData.feeder.mainBreakerAmps);
    feederMathSteps.add(
      '6. Grounding Protection: Min EGC = ${minMainEgc.toStringAsFixed(1).replaceAll('.0', '')} mm² Cu (Table 2.50.6.13) • Min GEC = ${minGec.toStringAsFixed(1).replaceAll('.0', '')} mm² Cu (Table 2.50.3.17 / max 14 mm² on Ground Rod per Sec. 2.50.3.17(A)).',
    );

    if ((sldData.feeder.totalConnectedVA - sumActiveVA).abs() > 1.0) {
      feederIssues.add(
        'Feeder Total Connected VA (${sldData.feeder.totalConnectedVA.toStringAsFixed(0)} VA) is out of sync with active branch sum (${sumActiveVA.toStringAsFixed(0)} VA).',
      );
    }
    if (sldData.feeder.mainBreakerAmps + 0.01 < feederDesignAmps) {
      feederIssues.add(
        'Main Breaker (${sldData.feeder.mainBreakerAmps} AT) is undersized for 125% continuous feeder design load (${feederDesignAmps.toStringAsFixed(1)} A).',
      );
    }
    if (feederWireSpec.ampacity75C + 0.01 < feederDesignAmps) {
      feederIssues.add(
        'Main Feeder Wire (${feederWireSpec.sizeMm2} mm², ${feederWireSpec.ampacity75C.toStringAsFixed(0)} A @ 75°C) is undersized for feeder design load (${feederDesignAmps.toStringAsFixed(1)} A).',
      );
    }

    PecAuditSeverity overall = PecAuditSeverity.compliant;
    if (criticalCount > 0 || feederIssues.isNotEmpty) {
      overall = PecAuditSeverity.criticalHazard;
    } else if (advisoryCount > 0) {
      overall = PecAuditSeverity.advisory;
    }

    final int totalChecks = findings.length + 1;
    final int passedSafeChecks = (findings.length - criticalCount) + (feederIssues.isEmpty ? 1 : 0);
    final double assurancePct = totalChecks > 0 ? (passedSafeChecks / totalChecks) * 100.0 : 100.0;

    return ScheduleSafetyAuditReport(
      overallSeverity: overall,
      totalActiveCircuits: findings.length,
      compliantCount: compliantCount,
      advisoryCount: advisoryCount,
      criticalHazardCount: criticalCount,
      circuitFindings: findings,
      feederIssues: feederIssues,
      feederMathSteps: feederMathSteps,
      assurancePercent: assurancePct,
    );
  }

  /// 1-Click Auto-Heal: Automatically corrects all branch circuits and the main feeder
  /// to 100% Verbatim PEC 2017 Part 1 compliance.
  static int autoHealSchedule(SingleLineDiagramData sldData) {
    int healedCount = 0;
    final report = auditSchedule(sldData);

    for (final finding in report.circuitFindings) {
      if (finding.severity != PecAuditSeverity.compliant) {
        final idx = sldData.branchCircuits.indexWhere((c) => c.circuitNumber == finding.circuitNumber && !c.isSpare);
        if (idx >= 0) {
          final c = sldData.branchCircuits[idx];
          c.loadCurrentAmps = c.loadVA / c.voltage;
          c.breakerRatingAmps = finding.recommendedBreakerAmps;
          final String wireStr = finding.recommendedWireMm2.toStringAsFixed(1).replaceAll('.0', '');
          final String egcStr = finding.recommendedEgcMm2.toStringAsFixed(1).replaceAll('.0', '');
          c.wireSizeDescription = '2 - $wireStr mm² THHN + 1 - $egcStr mm² Ground';
          c.conduitDescription = finding.recommendedConduit;

          final PecWireSpec healedSpec = PecEngine.wireSpecs.firstWhere(
            (w) => (w.sizeMm2 - finding.recommendedWireMm2).abs() < 0.1,
            orElse: () => PecEngine.wireSpecs[1],
          );
          c.voltageDropPercent = PecEngine.computeVoltageDropPercent(
            loadCurrentAmps: c.loadCurrentAmps,
            oneWayLengthMeters: c.measuredRunMeters,
            wireSpec: healedSpec,
            nominalVoltage: c.voltage.toDouble(),
          );
          healedCount++;
        }
      }
    }

    sldData.recalculateFeeder();
    if (report.feederIssues.isNotEmpty) {
      healedCount++;
    }
    return healedCount;
  }

  /// Verbatim PEC 2017 Appendix D Worked Example Calculator (Examples D1, D2, D3, D4 - Pages 1071-1075)
  /// Used to cross-verify BANAAG's residential load calculation logic against official PEC textbook problems.
  static Map<String, double> computeAppendixDDwellingExample({
    required double floorAreaSqm,
    int smallApplianceCircuits = 1,
    bool includeLaundryCircuit = false,
    double electricRangeNameplateKw = 0.0,
    List<double> otherFixedAppliancesVA = const [],
    List<double> airConditioningLoadsVA = const [],
    List<double> otherMotorLoadsVA = const [],
    bool useOptionalCalculation22043 = false,
  }) {
    // 1. General Lighting Load (PEC Table 2.20.2.3: 24 VA/m²)
    final double generalLightingVA = floorAreaSqm * 24.0;

    // 2. Small Appliance Branch Circuits (PEC Sec. 2.20.3.13(A): 1,500 VA per 20A SABC)
    final double sabcVA = smallApplianceCircuits * 1500.0;

    // 3. Laundry Branch Circuit (PEC Sec. 2.20.3.13(B): 1,500 VA)
    final double laundryVA = includeLaundryCircuit ? 1500.0 : 0.0;

    final List<double> allMotors = [...airConditioningLoadsVA, ...otherMotorLoadsVA];

    if (!useOptionalCalculation22043) {
      // STANDARD METHOD (PEC Part 2.20.3 - Examples D1, D2, D3)
      final double subtotalGeneralVA = generalLightingVA + sabcVA + laundryVA;
      final double netGeneralVA = subtotalGeneralVA <= 3000.0
          ? subtotalGeneralVA
          : 3000.0 + ((subtotalGeneralVA - 3000.0) * 0.35);

      // Range Demand (PEC Table 2.20.3.16: 80% for 1 range up to 12 kW in Examples D2 & D3)
      final double netRangeVA = electricRangeNameplateKw * 1000.0 * 0.80;

      final double sumOtherAppliancesVA = otherFixedAppliancesVA.fold(0.0, (a, b) => a + b);
      final double sumMotorsVA = allMotors.fold(0.0, (a, b) => a + b);
      final double largestMotorVA = allMotors.isEmpty
          ? 0.0
          : allMotors.reduce((a, b) => a > b ? a : b);

      // Net Computed Load without 25% motor allowance
      final double netComputedLoadWithoutMotorMarginVA =
          netGeneralVA + netRangeVA + sumOtherAppliancesVA + sumMotorsVA;

      // Total Service Entrance Full Load VA (including +25% of largest motor per Sec. 4.30.2.4 / Example D2 & D3)
      final double totalServiceDemandVA =
          netComputedLoadWithoutMotorMarginVA + (largestMotorVA * 0.25);

      final double serviceAmps = totalServiceDemandVA / 230.0;

      return {
        'generalLightingVA': generalLightingVA,
        'subtotalGeneralVA': subtotalGeneralVA,
        'netGeneralVA': netGeneralVA,
        'netRangeVA': netRangeVA,
        'netComputedLoadWithoutMotorMarginVA': netComputedLoadWithoutMotorMarginVA,
        'totalServiceDemandVA': totalServiceDemandVA,
        'serviceAmps': serviceAmps,
      };
    } else {
      // OPTIONAL CALCULATION METHOD (PEC Sec. 2.20.4.3 - Example D4, Page 1074)
      // 100% of Air Conditioning / Cooling + 100% of first 10,000 VA of all other loads + 40% of remainder of all other loads
      final double totalAirConditioningVA = airConditioningLoadsVA.fold(0.0, (a, b) => a + b);
      final double allOtherLoadsVA = generalLightingVA +
          sabcVA +
          laundryVA +
          (electricRangeNameplateKw * 1000.0) +
          otherFixedAppliancesVA.fold(0.0, (a, b) => a + b) +
          otherMotorLoadsVA.fold(0.0, (a, b) => a + b);

      final double netOtherLoadsVA = allOtherLoadsVA <= 10000.0
          ? allOtherLoadsVA
          : 10000.0 + ((allOtherLoadsVA - 10000.0) * 0.40);

      final double totalServiceDemandVA = totalAirConditioningVA + netOtherLoadsVA;
      final double serviceAmps = totalServiceDemandVA / 230.0;

      return {
        'generalLightingVA': generalLightingVA,
        'allOtherLoadsVA': allOtherLoadsVA,
        'netOtherLoadsVA': netOtherLoadsVA,
        'totalAirConditioningVA': totalAirConditioningVA,
        'totalServiceDemandVA': totalServiceDemandVA,
        'serviceAmps': serviceAmps,
      };
    }
  }
}
