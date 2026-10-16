import 'package:flutter_test/flutter_test.dart';
import 'package:banaag/domain/pec_engine.dart';
import 'package:banaag/domain/takeoff_engine.dart';
import 'package:banaag/domain/models.dart';

void main() {
  group('BANAAG PEC Engine Tests', () {
    test('Calculates wire size according to PEC Table 3.10.2.6', () {
      // 20A continuous load (20 * 1.25 = 25A) requires at least 3.5 mm² (#12 AWG)
      final wire = PecEngine.sizeWireForCurrent(20.0);
      expect(wire.sizeMm2, greaterThanOrEqualTo(3.5));
      expect(wire.ampacity75C, greaterThanOrEqualTo(25.0));
    });

    test('Flags conduit fill over 40% threshold', () {
      final wire = PecEngine.wireSpecs[2]; // 5.5 mm²
      final conduit = PecEngine.conduitSpecs[0]; // 20 mm conduit (201 mm²)
      // 8 conductors of 5.5mm² (8 * 16.3 = 130.4 mm² -> 130.4 / 201 = 64.8% fill)
      final fillRatio = PecEngine.computeConduitFillRatio(
        wireSpec: wire,
        conductorCount: 8,
        conduitSpec: conduit,
      );
      expect(fillRatio, greaterThan(40.0));
    });

    test('Smart Phase Balancer distributes VA loads evenly', () {
      final circuits = [
        {'name': 'C1', 'loadVA': 3000.0},
        {'name': 'C2', 'loadVA': 2500.0},
        {'name': 'C3', 'loadVA': 1500.0},
        {'name': 'C4', 'loadVA': 1000.0},
      ];
      final balanced = PecEngine.balanceSinglePhaseLines(circuits);
      final double vaA = (balanced['PhaseA'] as List).fold(0.0, (sum, c) => sum + (c['loadVA'] as double));
      final double vaB = (balanced['PhaseB'] as List).fold(0.0, (sum, c) => sum + (c['loadVA'] as double));

      // 8000 total VA -> perfectly splits into 4000 VA each
      expect(vaA, equals(4000.0));
      expect(vaB, equals(4000.0));
    });
  });

  group('BANAAG Takeoff Engine Tests', () {
    test('Includes 3D vertical drops and box splice allowances', () {
      final points = [
        CanvasPoint(id: 'p1', type: 'PANEL', label: 'Panel', x: 0, y: 0),
        CanvasPoint(id: 'p2', type: 'SWITCH_1G', label: 'Switch', x: 10, y: 0),
        CanvasPoint(id: 'p3', type: 'LIGHT', label: 'Light', x: 20, y: 0),
      ];
      final routes = [
        ConduitRoute(id: 'r1', fromPointId: 'p1', toPointId: 'p2', measuredLengthMeters: 5.0),
        ConduitRoute(id: 'r2', fromPointId: 'p2', toPointId: 'p3', measuredLengthMeters: 3.0),
      ];

      final takeoff = TakeoffEngine.calculate(points: points, routes: routes);

      // Horizontal = 8m, Vertical = 1.8m (panel) + 1.2m (switch) = 3.0m
      expect(takeoff.horizontalConduitMeters, equals(8.0));
      expect(takeoff.verticalDropMeters, equals(3.0));
      expect(takeoff.totalConduitMeters, equals(11.0));
      expect(takeoff.totalPvcPipesPcs, equals(4)); // 11m / 3m = 3.66 -> 4 pipes
    });
  });
}
