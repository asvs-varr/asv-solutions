// BANAAG Auto-Room & Illuminance Placement Service
// Takes user custom dimensions (Length, Width, Height) and selected RoomType (Residential, Institutional, Commercial)
// and computes exact IESNA d/2 symmetrical lighting layout, switches, and homerun conduit connections.

import 'models.dart';
import 'lighting_engine.dart';
import 'illuminance_grid_engine.dart';

class RoomIlluminancePlacementResult {
  final RoomGeometry geometry;
  final List<CanvasPoint> points;
  final List<ConduitRoute> routes;
  final IlluminanceLayoutResult illuminanceResult;

  const RoomIlluminancePlacementResult({
    required this.geometry,
    required this.points,
    required this.routes,
    required this.illuminanceResult,
  });
}

class RoomIlluminancePlacementService {
  /// Builds a complete electrical room layout from user dimensions and occupancy type.
  static RoomIlluminancePlacementResult generate({
    required double lengthMeters,
    required double widthMeters,
    double ceilingHeightMeters = 2.8,
    required RoomType roomType,
    String existingPanelId = 'pt-panel',
  }) {
    final safeL = lengthMeters <= 0 ? 6.0 : lengthMeters;
    final safeW = widthMeters <= 0 ? 5.0 : widthMeters;
    final areaSqm = safeL * safeW;

    // 1. Compute IESNA Symmetrical Grid & Photometric Uniformity
    final illumResult = IlluminanceGridEngine.computeLayout(
      lengthMeters: safeL,
      widthMeters: safeW,
      ceilingHeightMeters: ceilingHeightMeters,
      roomType: roomType,
    );

    // 2. Room Geometry on Canvas
    final geometry = RoomGeometry(
      leftWallMeters: safeW,
      totalWidthMeters: safeL,
      roomType: 'RECTANGULAR',
    );

    // Canvas coordinate mapping:
    // Origin at (60, 60), Scale: ~40 to 50 px/m depending on room extent
    const double originX = 60.0;
    const double originY = 60.0;
    final double scale = (300.0 / (safeL > safeW ? safeL : safeW)).clamp(20.0, 50.0);

    final List<CanvasPoint> points = [];
    final List<ConduitRoute> routes = [];

    // 3. Panelboard (LP-1) at entrance left wall
    final panelPt = CanvasPoint(
      id: existingPanelId,
      type: 'PANEL',
      label: 'LP-1',
      x: originX + 15,
      y: originY + (safeW * scale) - 20,
      circuitNumber: 1,
    );
    points.add(panelPt);

    // 4. Wall Switch (S1, S2, or S3w) beside door opening
    final switchId = 'pt-sw-room';
    final isMultiSwitch = illumResult.totalFixtures >= 4;
    final switchLabel = isMultiSwitch ? 'S2a,b' : 'S1a';
    final switchPt = CanvasPoint(
      id: switchId,
      type: 'SWITCH_1G',
      label: switchLabel,
      x: originX + 45,
      y: originY + (safeW * scale) - 20,
      circuitNumber: 1,
    );
    points.add(switchPt);

    // Route from Panel to Switch
    routes.add(ConduitRoute(
      id: 'rt-pnl-sw',
      fromPointId: panelPt.id,
      toPointId: switchPt.id,
      measuredLengthMeters: 1.5,
      conductorCount: 2,
    ));

    // 5. Place IESNA Fixtures inside room
    final List<String> fixturePointIds = [];
    for (int i = 0; i < illumResult.fixtures.length; i++) {
      final f = illumResult.fixtures[i];
      final fId = 'pt-fix-${i + 1}';
      fixturePointIds.add(fId);

      final px = originX + (f.xMeters * scale);
      final py = originY + (f.yMeters * scale);

      points.add(CanvasPoint(
        id: fId,
        type: 'LIGHT',
        label: f.label,
        x: px,
        y: py,
        circuitNumber: 1,
      ));
    }

    // 6. Connect Switch to Fixtures with Daisy-Chain Conduit Arcs
    if (fixturePointIds.isNotEmpty) {
      routes.add(ConduitRoute(
        id: 'rt-sw-fix1',
        fromPointId: switchPt.id,
        toPointId: fixturePointIds.first,
        measuredLengthMeters: 2.5,
        conductorCount: 2,
      ));

      for (int i = 0; i < fixturePointIds.length - 1; i++) {
        routes.add(ConduitRoute(
          id: 'rt-fix-$i',
          fromPointId: fixturePointIds[i],
          toPointId: fixturePointIds[i + 1],
          measuredLengthMeters: illumResult.spacingXMeters > 0 ? illumResult.spacingXMeters : 2.5,
          conductorCount: 2,
        ));
      }
    }

    // 7. Convenience Outlets based on Occupancy (PEC Art 2.10)
    final co1 = CanvasPoint(
      id: 'pt-co-1',
      type: 'OUTLET_DUPLEX',
      label: 'Duplex CO (Left Wall)',
      x: originX + 15,
      y: originY + ((safeW / 2) * scale),
      circuitNumber: 2,
    );
    final co2 = CanvasPoint(
      id: 'pt-co-2',
      type: 'OUTLET_DUPLEX',
      label: 'Duplex CO (Right Wall)',
      x: originX + (safeL * scale) - 15,
      y: originY + ((safeW / 2) * scale),
      circuitNumber: 2,
    );
    points.add(co1);
    points.add(co2);

    routes.add(ConduitRoute(
      id: 'rt-pnl-co1',
      fromPointId: panelPt.id,
      toPointId: co1.id,
      measuredLengthMeters: 3.5,
      conductorCount: 3,
    ));
    routes.add(ConduitRoute(
      id: 'rt-co1-co2',
      fromPointId: co1.id,
      toPointId: co2.id,
      measuredLengthMeters: safeL,
      conductorCount: 3,
    ));

    // 8. Dedicated Aircon Unit (ACU) sizing based on floor area
    final String acuLabel;
    if (areaSqm <= 12.0) {
      acuLabel = '1.0HP Inverter ACU';
    } else if (areaSqm <= 22.0) {
      acuLabel = '1.5HP Inverter ACU';
    } else if (areaSqm <= 35.0) {
      acuLabel = '2.0HP Inverter ACU';
    } else {
      acuLabel = '2.5HP Inverter ACU';
    }

    final acuPt = CanvasPoint(
      id: 'pt-acu',
      type: 'ACU',
      label: acuLabel,
      x: originX + (safeL * scale) - 25,
      y: originY + 25,
      circuitNumber: 3,
    );
    points.add(acuPt);

    routes.add(ConduitRoute(
      id: 'rt-pnl-acu',
      fromPointId: panelPt.id,
      toPointId: acuPt.id,
      measuredLengthMeters: safeL + safeW,
      conductorCount: 3,
    ));

    return RoomIlluminancePlacementResult(
      geometry: geometry,
      points: points,
      routes: routes,
      illuminanceResult: illumResult,
    );
  }
}
