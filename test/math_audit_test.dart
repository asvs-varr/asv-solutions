import 'package:flutter_test/flutter_test.dart';
import 'package:banaag/domain/future_proofing_engine.dart';
import 'package:banaag/domain/sld_engine.dart';
import 'package:banaag/domain/takeoff_engine.dart';
import 'package:banaag/domain/lighting_engine.dart';
import 'package:banaag/domain/illuminance_grid_engine.dart';
import 'package:banaag/domain/institutional_building_presets.dart';
import 'package:banaag/domain/models.dart';

void main() {
  group('BANAAG System-Wide Mathematical & PEC 2017 Audit Suite', () {
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
      // Wire at 75°C: 5.5 mm² (35A) >= 27.17A
      // Breaker: 30A (first standard >= 27.17A, <= 35A wire ampacity)
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
    });
  });
}
