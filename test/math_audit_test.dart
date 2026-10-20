import 'package:flutter_test/flutter_test.dart';
import 'package:banaag/domain/pec_engine.dart';
import 'package:banaag/domain/pec_safety_auditor.dart';
import 'package:banaag/domain/future_proofing_engine.dart';
import 'package:banaag/domain/sld_engine.dart';
import 'package:banaag/domain/takeoff_engine.dart';
import 'package:banaag/domain/lighting_engine.dart';
import 'package:banaag/domain/illuminance_grid_engine.dart';
import 'package:banaag/domain/institutional_building_presets.dart';
import 'package:banaag/domain/models.dart';

void main() {
  group('BANAAG System-Wide Mathematical & Verbatim PEC 2017 Audit Suite', () {
    test('1. FutureProofingEngine applies 125% continuous factor exactly once (Solar & EV)', () {
      // 7.4 kW EV Charger @ 230V:
      // I_rated = 7400 / 230 = 32.1739 A
      // I_continuous (125%) = 32.1739 * 1.25 = 40.2174 A
      // Wire at 75°C: 8.0 mm² (50A) >= 40.22A
      // Breaker: 50A (first standard >= 40.22A, <= 50A wire ampacity)
      final ev = FutureProofingEngine.calculateEvCharger(7.4);
      expect(ev.continuousCurrentAmps, closeTo(40.2174, 0.01));
      expect(ev.recommendedWire.sizeMm2, equals(8.0));
      expect(ev.recommendedBreaker, equals(50));

      // 5.0 kW Solar PV @ 230V:
      // I_rated = 5000 / 230 = 21.7391 A
      // I_continuous (125%) = 21.7391 * 1.25 = 27.1739 A
      // Wire at 75°C: 5.5 mm² (35A, max OCPD 30A per Sec. 2.40.1.4(D)) >= 27.17A
      // Breaker: 30A (first standard >= 27.17A, <= 30A small conductor rule)
      final solar = FutureProofingEngine.calculateSolarReadiness(5.0);
      expect(solar.inverterAcOutputAmps, closeTo(21.7391, 0.01));
      expect(solar.recommendedWire.sizeMm2, equals(5.5));
      expect(solar.recommendedBreaker, equals(30));
    });

    test('2. SldEngine includes SABC in 35% Demand Factor & adds 25% Largest Motor Load', () {
      final project = Project(
        id: 'test-1',
        title: 'Residential Math Audit',
        clientName: 'Engr. Test',
        clientContact: '09170000000',
        siteAddress: 'Manila',
        contractAmount: 50000,
        createdAt: DateTime.now(),
        spaces: [],
        applianceLoads: [
          ApplianceItem(
            id: 'a1',
            name: 'LED Downlights',
            roomCategory: 'Living',
            ratingVA: 1000.0,
            quantity: 1,
            isLighting: true,
          ),
          ApplianceItem(
            id: 'a2',
            name: 'Kitchen SABC Countertop Outlets',
            roomCategory: 'Kitchen',
            ratingVA: 1800.0,
            quantity: 1,
            isDedicatedCircuit: false,
          ),
          ApplianceItem(
            id: 'a3',
            name: 'Living Room Convenience Outlets',
            roomCategory: 'Living',
            ratingVA: 1440.0,
            quantity: 1,
            isDedicatedCircuit: false,
          ),
          ApplianceItem(
            id: 'a4',
            name: '2.0HP Split Type Inverter ACU',
            roomCategory: 'Master Bedroom',
            ratingVA: 2000.0,
            quantity: 1,
            isDedicatedCircuit: true,
          ),
          ApplianceItem(
            id: 'a5',
            name: 'Multipoint Water Heater',
            roomCategory: 'Bath',
            ratingVA: 3500.0,
            quantity: 1,
            isDedicatedCircuit: true,
          ),
        ],
        phases: [],
      );

      final sld = SldEngine.generateFromProject(project);
      // Total Connected = 1000 (Light) + 1800 (SABC) + 1440 (Conv) + 2000 (ACU) + 3500 (Heater) = 9740 VA
      expect(sld.feeder.totalConnectedVA, closeTo(9740.0, 0.01));

      // General + SABC + Conv = 1000 + 1800 + 1440 = 4240 VA
      // Net General = 3000 + (1240 * 0.35) = 3000 + 434 = 3434 VA
      // Dedicated = 2000 + 3500 = 5500 VA
      // 25% of Largest Motor (2000 VA ACU) = 500 VA
      // Total Net Demand = 3434 + 5500 + 500 = 9434 VA
      expect(sld.feeder.netDemandVA, closeTo(9434.0, 0.01));
      expect(sld.feeder.netCurrentAmps, closeTo(9434.0 / 230.0, 0.01));
    });

    test('3. Default Residential SLD uses exact 35% PEC Demand Factor + 25% Largest Motor', () {
      final emptyProject = Project(
        id: 'test-empty',
        title: 'Default SLD Audit',
        clientName: 'Client',
        clientContact: '000',
        siteAddress: 'Address',
        contractAmount: 0,
        createdAt: DateTime.now(),
        spaces: [],
        applianceLoads: [],
        phases: [],
      );
      final sld = SldEngine.generateFromProject(emptyProject);
      // General + Kitchen = 650 + 520 + 1440 + 1800 = 4410 VA -> 3000 + 1410*0.35 = 3493.5 VA
      // Dedicated = 1950 (ACU) + 3500 (Heater) = 5450 VA
      // 25% of 1950 VA ACU = 487.5 VA
      // Total Net Demand = 3493.5 + 5450 + 487.5 = 9431.0 VA
      expect(sld.feeder.totalConnectedVA, closeTo(9860.0, 0.01));
      expect(sld.feeder.netDemandVA, closeTo(9431.0, 0.01));
    });

    test('4. TakeoffEngine handles FAN points and matches BOM itemized costs 100%', () {
      final points = [
        CanvasPoint(id: 'p1', type: 'PANEL', label: 'LP-1', x: 50, y: 370),
        CanvasPoint(id: 'p2', type: 'LIGHT', label: 'L1', x: 80, y: 170),
        CanvasPoint(id: 'p3', type: 'FAN', label: 'F1', x: 110, y: 170),
        CanvasPoint(id: 'p4', type: 'SWITCH_1G', label: 'S1', x: 60, y: 156),
        CanvasPoint(id: 'p5', type: 'OUTLET_DUPLEX', label: 'CO1', x: 90, y: 156),
      ];
      final routes = [
        ConduitRoute(id: 'r1', fromPointId: 'p1', toPointId: 'p2', measuredLengthMeters: 12.0),
      ];

      final takeoff = TakeoffEngine.calculate(points: points, routes: routes);
      // LIGHT (1) + FAN (1) = 2 octagonal boxes
      expect(takeoff.octagonalBoxesCount, equals(2));
      // SWITCH_1G (1) + OUTLET_DUPLEX (1) = 2 utility boxes
      expect(takeoff.utilityBoxesCount, equals(2));
      expect(
        takeoff.grandTotalEstimatedCost,
        closeTo(takeoff.estimatedMaterialCost + takeoff.estimatedLaborCost, 0.001),
      );
    });

    test('5. IlluminanceGridEngine matches LightingEngine.calculate().fixtureCount 100%', () {
      for (final roomType in RoomType.values) {
        for (final area in [9.0, 14.0, 18.0, 24.0, 32.0]) {
          final length = area / 4.0;
          const width = 4.0;
          final rec = LightingEngine.calculate(
            roomType: roomType,
            areaSqm: area,
            ceilingHeightMeters: 2.7,
          );
          final grid = IlluminanceGridEngine.computeLayout(
            roomType: roomType,
            lengthMeters: length,
            widthMeters: width,
            ceilingHeightMeters: 2.7,
          );
          expect(grid.totalFixtures, equals(rec.fixtureCount));
          expect(grid.fixtures.length, equals(rec.fixtureCount));
        }
      }
    });

    test('6. MultiPanelInstitutionalRiser sizes MDP feeder wire >= breaker rating at 75C', () {
      final preset = InstitutionalBuildingPreset.sanLorenzoRuizCollege();
      final riser = MultiPanelInstitutionalRiser.compute(preset);
      expect(
        riser.mdp.feeder.netDemandVA,
        closeTo((riser.lp1.feeder.netDemandVA + riser.lp2.feeder.netDemandVA) * 0.90, 0.01),
      );
      // Verify all institutional sub-panels pass 100% Verbatim PEC 2017 safety audit
      final lp1Audit = PecSafetyAuditor.auditSchedule(riser.lp1);
      final lp2Audit = PecSafetyAuditor.auditSchedule(riser.lp2);
      expect(lp1Audit.criticalHazardCount, equals(0));
      expect(lp2Audit.criticalHazardCount, equals(0));
    });

    test('7. Lock #3: Immutable Verbatim PEC 2017 Table 3.10.2.6(B)(16) (Page 174) & Sec. 2.40.1.4(D) (Page 84)', () {
      // Exact cell-by-cell verification of PEC 2017 Table 3.10.2.6(B)(16) Copper Ampacities (60°C, 75°C, 90°C)
      final expectedSpecs = <double, List<double>>{
        // sizeMm2: [amp60C, amp75C, amp90C, effectiveMaxBranchAmps]
        2.0: [15.0, 20.0, 25.0, 15.0],
        3.5: [20.0, 25.0, 30.0, 20.0],
        5.5: [30.0, 35.0, 40.0, 30.0],
        8.0: [40.0, 50.0, 55.0, 50.0],
        14.0: [55.0, 65.0, 75.0, 65.0],
        22.0: [70.0, 85.0, 95.0, 85.0],
        30.0: [85.0, 100.0, 115.0, 100.0],
        38.0: [100.0, 115.0, 130.0, 115.0],
        50.0: [115.0, 140.0, 150.0, 140.0],
        60.0: [130.0, 155.0, 170.0, 155.0],
        80.0: [155.0, 190.0, 205.0, 190.0],
        100.0: [185.0, 220.0, 240.0, 220.0],
        125.0: [210.0, 255.0, 285.0, 255.0],
        150.0: [240.0, 285.0, 320.0, 285.0],
        200.0: [275.0, 325.0, 360.0, 325.0],
        250.0: [315.0, 375.0, 425.0, 375.0],
      };

      expect(PecEngine.wireSpecs.length, equals(expectedSpecs.length));
      for (final spec in PecEngine.wireSpecs) {
        final expected = expectedSpecs[spec.sizeMm2];
        expect(expected, isNotNull, reason: 'Missing expected spec for ${spec.sizeMm2} mm²');
        expect(spec.ampacity60C, equals(expected![0]), reason: '${spec.sizeMm2} mm² 60°C mismatch');
        expect(spec.ampacity75C, equals(expected[1]), reason: '${spec.sizeMm2} mm² 75°C mismatch');
        expect(spec.ampacity90C, equals(expected[2]), reason: '${spec.sizeMm2} mm² 90°C mismatch');
        expect(spec.effectiveMaxBranchAmps, equals(expected[3]), reason: '${spec.sizeMm2} mm² Sec. 2.40.1.4(D) cap mismatch');
      }

      // Verify Sec. 2.40.1.4(D) Small Conductor Rule enforcement:
      // A 18A continuous load (18 * 1.25 = 22.5A) CANNOT use 3.5 mm² because 3.5 mm² is capped at 20A OCPD!
      final wireFor18A = PecEngine.sizeWireForCurrent(18.0, isContinuous: true);
      expect(wireFor18A.sizeMm2, equals(5.5));
      final breakerFor18A = PecEngine.selectBreaker(
        18.0,
        wireFor18A.ampacity75C,
        isContinuous: true,
        wireSizeMm2: wireFor18A.sizeMm2,
      );
      expect(breakerFor18A, equals(30));
    });

    test('8. Lock #3: Immutable Verbatim PEC 2017 Table 2.40.1.6(A) (Page 86) & Table 10.1.1.4 (Page 935)', () {
      // Standard Ampere Ratings (must NOT contain non-standard 75A)
      expect(
        PecEngine.standardBreakers,
        equals([15, 20, 25, 30, 35, 40, 45, 50, 60, 70, 80, 90, 100, 110, 125, 150, 175, 200, 225, 250, 300, 350, 400]),
      );
      expect(PecEngine.standardBreakers.contains(75), isFalse);

      // Schedule 40 PVC Conduit Internal Areas & 40% Fill (PEC Table 10.1.1.4, Page 935)
      final expectedConduits = <int, List<double>>{
        15: [184.0, 74.0],
        20: [327.0, 131.0],
        25: [535.0, 214.0],
        32: [935.0, 374.0],
        40: [1282.0, 513.0],
        50: [2124.0, 849.0],
        65: [3029.0, 1212.0],
        80: [4693.0, 1877.0],
      };
      for (final c in PecEngine.conduitSpecs) {
        final exp = expectedConduits[c.metricDesignatorMm]!;
        expect(c.internalAreaMm2, equals(exp[0]));
        expect(c.area40PercentMm2, equals(exp[1]));
      }
    });

    test('9. Lock #3: Ambient/Raceway Derating & Grounding Tables 2.50.3.17 / 2.50.6.13', () {
      // Ambient Temp Factor at 35°C (75°C column) = 0.94; at 40°C = 0.88
      expect(PecEngine.getAmbientTemperatureCorrectionFactor(35.0), closeTo(0.94, 0.001));
      expect(PecEngine.getAmbientTemperatureCorrectionFactor(40.0), closeTo(0.88, 0.001));

      // Raceway Bundling Factor: 3 wires = 1.00; 4-6 wires = 0.80; 7-9 wires = 0.70
      expect(PecEngine.getBundlingAdjustmentFactor(3), closeTo(1.00, 0.001));
      expect(PecEngine.getBundlingAdjustmentFactor(6), closeTo(0.80, 0.001));
      expect(PecEngine.getBundlingAdjustmentFactor(9), closeTo(0.70, 0.001));

      // Grounding Electrode Conductor (Table 2.50.3.17, Page 113):
      // <=30 mm² -> 8.0 mm²; 38-50 mm² -> 14.0 mm²; 60-80 mm² -> 22.0 mm² (capped at 14.0 mm² for rod electrode per Sec. 2.50.3.17(A))
      expect(PecEngine.getMinimumGroundingElectrodeConductorMm2(22.0), equals(8.0));
      expect(PecEngine.getMinimumGroundingElectrodeConductorMm2(50.0), equals(14.0));
      expect(PecEngine.getMinimumGroundingElectrodeConductorMm2(80.0, connectedSolelyToRodPipeOrPlate: false), equals(22.0));
      expect(PecEngine.getMinimumGroundingElectrodeConductorMm2(80.0, connectedSolelyToRodPipeOrPlate: true), equals(14.0));

      // Equipment Grounding Conductor (Table 2.50.6.13, Page 124):
      expect(PecEngine.getMinimumEquipmentGroundingConductorMm2(15), equals(2.0));
      expect(PecEngine.getMinimumEquipmentGroundingConductorMm2(20), equals(3.5));
      expect(PecEngine.getMinimumEquipmentGroundingConductorMm2(60), equals(5.5));
      expect(PecEngine.getMinimumEquipmentGroundingConductorMm2(100), equals(8.0));
      expect(PecEngine.getMinimumEquipmentGroundingConductorMm2(200), equals(14.0));
    });

    test('10. Official PEC 2017 Appendix D Worked Examples D1, D2, D3, and D4 (Pages 1071-1075)', () {
      // EXAMPLE D1 (Page 1071): Single Family Dwelling with 45 m² floor area
      final d1 = PecSafetyAuditor.computeAppendixDDwellingExample(
        floorAreaSqm: 45.0,
        smallApplianceCircuits: 1,
      );
      expect(d1['generalLightingVA'], closeTo(1080.0, 0.01));
      expect(d1['subtotalGeneralVA'], closeTo(2580.0, 0.01));
      expect(d1['serviceAmps'], closeTo(2580.0 / 230.0, 0.01)); // 11.22 A <= 16A (20A branch circuit permitted)

      // EXAMPLE D2 (Page 1072): Single Family Dwelling, 145 m² floor area, Standard Calculation
      final d2 = PecSafetyAuditor.computeAppendixDDwellingExample(
        floorAreaSqm: 145.0,
        smallApplianceCircuits: 1,
        electricRangeNameplateKw: 10.0,
        airConditioningLoadsVA: [1840.0, 2300.0], // 1-HP (8A) + 1.5-HP (10A)
        otherMotorLoadsVA: [1127.0], // 1/2-HP Water Pump (4.9A)
      );
      expect(d2['generalLightingVA'], closeTo(3480.0, 0.01));
      expect(d2['subtotalGeneralVA'], closeTo(4980.0, 0.01));
      expect(d2['netGeneralVA'], closeTo(3693.0, 0.01));
      expect(d2['netRangeVA'], closeTo(8000.0, 0.01));
      expect(d2['netComputedLoadWithoutMotorMarginVA'], closeTo(16960.0, 0.01));
      expect(d2['totalServiceDemandVA'], closeTo(17535.0, 0.01)); // +25% of 2,300 VA = +575 VA

      // EXAMPLE D3 (Page 1073): Single Family Dwelling, 140 m² floor area, Standard Calculation
      final d3 = PecSafetyAuditor.computeAppendixDDwellingExample(
        floorAreaSqm: 140.0,
        smallApplianceCircuits: 1,
        includeLaundryCircuit: true,
        electricRangeNameplateKw: 12.0,
        otherFixedAppliancesVA: [2500.0, 1200.0], // 2.5 kW Water Heater + 1.2 kW Dishwasher
        airConditioningLoadsVA: [2300.0, 2760.0], // 1.5-HP ACU + 2-HP ACU
        otherMotorLoadsVA: [1840.0], // 1-HP Water Pump
      );
      expect(d3['generalLightingVA'], closeTo(3360.0, 0.01));
      expect(d3['subtotalGeneralVA'], closeTo(6360.0, 0.01));
      expect(d3['netGeneralVA'], closeTo(4176.0, 0.01));
      expect(d3['netRangeVA'], closeTo(9600.0, 0.01));
      expect(d3['netComputedLoadWithoutMotorMarginVA'], closeTo(24376.0, 0.01));
      expect(d3['totalServiceDemandVA'], closeTo(25066.0, 0.01)); // +25% of 2,760 VA = +690 VA
      expect(d3['serviceAmps'], closeTo(108.98, 0.01));

      // EXAMPLE D4 (Page 1074): Same 140 m² Dwelling via Optional Calculation Method (Sec. 2.20.4.3)
      final d4 = PecSafetyAuditor.computeAppendixDDwellingExample(
        floorAreaSqm: 140.0,
        smallApplianceCircuits: 1,
        includeLaundryCircuit: true,
        electricRangeNameplateKw: 12.0,
        otherFixedAppliancesVA: [2500.0, 1200.0],
        airConditioningLoadsVA: [2300.0, 2760.0],
        otherMotorLoadsVA: [1840.0],
        useOptionalCalculation22043: true,
      );
      expect(d4['totalAirConditioningVA'], closeTo(5060.0, 0.01));
      expect(d4['allOtherLoadsVA'], closeTo(23900.0, 0.01));
      expect(d4['netOtherLoadsVA'], closeTo(15560.0, 0.01)); // 10,000 + 40% of 13,900
      expect(d4['totalServiceDemandVA'], closeTo(20620.0, 0.01));
      expect(d4['serviceAmps'], closeTo(89.65, 0.01));
    });

    test('11. Lock #1 & Lock #2: PecSafetyAuditor detects UNDER-SPECS hazards, blocks export, and Auto-Heals to 100%', () {
      final emptyProject = Project(
        id: 'test-audit',
        title: 'Safety Interlock Audit',
        clientName: 'Client',
        clientContact: '000',
        siteAddress: 'Address',
        contractAmount: 0,
        createdAt: DateTime.now(),
        spaces: [],
        applianceLoads: [],
        phases: [],
      );
      final sld = SldEngine.generateFromProject(emptyProject);

      // Initially 100% compliant
      final initialAudit = PecSafetyAuditor.auditSchedule(sld);
      expect(initialAudit.criticalHazardCount, equals(0));
      expect(initialAudit.isExportBlocked, isFalse);
      expect(initialAudit.assurancePercent, equals(100.0));

      // Inject a dangerous UNDER-SPECS violation on Circuit 6 (3,500 VA Water Heater on 2.0 mm² wire & 30A breaker)
      final heaterCircuit = sld.branchCircuits.firstWhere((c) => c.circuitNumber == 6);
      heaterCircuit.wireSizeDescription = '2 - 2.0 mm² THHN + 1 - 2.0 mm² Ground';
      heaterCircuit.breakerRatingAmps = 30;

      final hazardAudit = PecSafetyAuditor.auditSchedule(sld);
      expect(hazardAudit.overallSeverity, equals(PecAuditSeverity.criticalHazard));
      expect(hazardAudit.criticalHazardCount, greaterThanOrEqualTo(1));
      expect(hazardAudit.isExportBlocked, isTrue);

      // Execute 1-Click Auto-Heal
      final healedCount = PecSafetyAuditor.autoHealSchedule(sld);
      expect(healedCount, greaterThanOrEqualTo(1));

      // Re-audit after Auto-Heal: must be 100% compliant and export unblocked
      final postHealAudit = PecSafetyAuditor.auditSchedule(sld);
      expect(postHealAudit.criticalHazardCount, equals(0));
      expect(postHealAudit.isExportBlocked, isFalse);
      expect(postHealAudit.assurancePercent, equals(100.0));
      expect(heaterCircuit.wireSizeDescription, contains('3.5 mm² THHN'));
      expect(heaterCircuit.breakerRatingAmps, equals(20));
    });
  });
}
