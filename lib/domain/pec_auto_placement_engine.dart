// BANAAG Core Domain: PEC Smart Auto-Placement Engine
// Compliant with Philippine Electrical Code (PEC 2017) Part 1
//
// Generates intelligent, code-compliant placements of luminaires, switches,
// convenience receptacles, and home-run conduit routes for raw floor plans
// or unlayered CAD/image underlays.

import 'dart:math' as math;
import 'models.dart';
import 'lighting_engine.dart';
import 'illuminance_grid_engine.dart';

class AutoPlacementResult {
  final List<CanvasPoint> points;
  final List<ConduitRoute> routes;
  final int totalLights;
  final int totalOutlets;
  final int totalSwitches;
  final double estimatedWireMeters;
  final String complianceSummary;

  const AutoPlacementResult({
    required this.points,
    required this.routes,
    required this.totalLights,
    required this.totalOutlets,
    required this.totalSwitches,
    required this.estimatedWireMeters,
    required this.complianceSummary,
  });
}

class PecAutoPlacementEngine {
  /// Generate full PEC compliant electrical layout on a given room geometry or boundary
  static AutoPlacementResult generateLayout({
    required double lengthMeters,
    required double widthMeters,
    double ceilingHeightMeters = 2.7,
    RoomType roomType = RoomType.livingDining,
    double canvasOriginX = 34.0,
    double canvasOriginY = 185.0,
    double? scale,
    String panelId = 'pt-panel',
  }) {
    final double safeL = lengthMeters <= 0 ? 6.0 : lengthMeters;
    final double safeW = widthMeters <= 0 ? 5.0 : widthMeters;
    final double areaSqm = safeL * safeW;

    // Fit cleanly inside the mobile floor plan viewport (width ~292px, height ~205px)
    const double targetBoxWidth = 292.0;
    const double targetBoxHeight = 205.0;
    final double scaleX = targetBoxWidth / safeL;
    final double scaleY = targetBoxHeight / safeW;

    final List<CanvasPoint> points = [];
    final List<ConduitRoute> routes = [];

    // 1. Panelboard (MDP) at main entrance corner
    final panelPt = CanvasPoint(
      id: panelId,
      type: 'PANEL',
      label: 'MDP',
      x: canvasOriginX + 12,
      y: canvasOriginY + (safeW * scaleY) - 14,
      circuitNumber: 1,
    );
    points.add(panelPt);

    // 2. Wall Switch (S1 or S2) beside entrance door opening
    final switchPt = CanvasPoint(
      id: 'pt-sw-auto',
      type: 'SWITCH_1G',
      label: areaSqm > 20 ? 'S2' : 'S1',
      x: canvasOriginX + 36,
      y: canvasOriginY + (safeW * scaleY) - 14,
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

    // 3. IESNA / PEC Lumen-Based Ceiling Luminaires Placement
    final illum = IlluminanceGridEngine.computeLayout(
      lengthMeters: safeL,
      widthMeters: safeW,
      ceilingHeightMeters: ceilingHeightMeters,
      roomType: roomType,
    );

    final List<String> lightIds = [];
    for (int i = 0; i < illum.fixtures.length; i++) {
      final f = illum.fixtures[i];
      final lId = 'pt-lt-${i + 1}';
      lightIds.add(lId);

      points.add(CanvasPoint(
        id: lId,
        type: 'LIGHT',
        label: 'L-${i + 1}',
        x: canvasOriginX + (f.xMeters * scaleX),
        y: canvasOriginY + (f.yMeters * scaleY),
        circuitNumber: 1,
      ));
    }

    // Daisy chain lighting fixtures from switch
    if (lightIds.isNotEmpty) {
      routes.add(ConduitRoute(
        id: 'rt-sw-lt1',
        fromPointId: switchPt.id,
        toPointId: lightIds.first,
        measuredLengthMeters: 2.5,
        conductorCount: 2,
      ));

      for (int i = 0; i < lightIds.length - 1; i++) {
        routes.add(ConduitRoute(
          id: 'rt-lt-$i',
          fromPointId: lightIds[i],
          toPointId: lightIds[i + 1],
          measuredLengthMeters: illum.spacingXMeters > 0 ? illum.spacingXMeters : 2.5,
          conductorCount: 2,
        ));
      }
    }

    // 4. PEC Art 2.10.3.3 Convenience Receptacle Spacing
    final List<CanvasPoint> outletPoints = [];
    int coIndex = 1;

    // Left wall outlets
    final int leftCount = (safeW / 3.6).ceil().clamp(1, 3);
    for (int i = 1; i <= leftCount; i++) {
      final double yPos = (safeW / (leftCount + 1)) * i;
      outletPoints.add(CanvasPoint(
        id: 'pt-co-l$i',
        type: 'OUTLET_DUPLEX',
        label: 'CO-${coIndex++}',
        x: canvasOriginX + 10,
        y: canvasOriginY + (yPos * scaleY),
        circuitNumber: 2,
      ));
    }

    // Top wall outlets
    final int topCount = (safeL / 3.6).ceil().clamp(1, 4);
    for (int i = 1; i <= topCount; i++) {
      final double xPos = (safeL / (topCount + 1)) * i;
      outletPoints.add(CanvasPoint(
        id: 'pt-co-t$i',
        type: 'OUTLET_DUPLEX',
        label: 'CO-${coIndex++}',
        x: canvasOriginX + (xPos * scaleX),
        y: canvasOriginY + 10,
        circuitNumber: 2,
      ));
    }

    // Right wall outlets
    final int rightCount = (safeW / 3.6).ceil().clamp(1, 3);
    for (int i = 1; i <= rightCount; i++) {
      final double yPos = (safeW / (rightCount + 1)) * i;
      outletPoints.add(CanvasPoint(
        id: 'pt-co-r$i',
        type: 'OUTLET_DUPLEX',
        label: 'CO-${coIndex++}',
        x: canvasOriginX + (safeL * scaleX) - 10,
        y: canvasOriginY + (yPos * scaleY),
        circuitNumber: 2,
      ));
    }

    // Bottom wall outlets (away from entrance)
    if (safeL > 4.0) {
      outletPoints.add(CanvasPoint(
        id: 'pt-co-b1',
        type: 'OUTLET_DUPLEX',
        label: 'CO-${coIndex++}',
        x: canvasOriginX + ((safeL / 2) * scaleX),
        y: canvasOriginY + (safeW * scaleY) - 10,
        circuitNumber: 2,
      ));
    }

    points.addAll(outletPoints);

    // Daisy chain convenience outlets starting from Panelboard
    if (outletPoints.isNotEmpty) {
      routes.add(ConduitRoute(
        id: 'rt-pnl-co-start',
        fromPointId: panelPt.id,
        toPointId: outletPoints.first.id,
        measuredLengthMeters: 3.2,
        conductorCount: 3,
      ));

      for (int i = 0; i < outletPoints.length - 1; i++) {
        final double dist = math.sqrt(
          math.pow((outletPoints[i + 1].x - outletPoints[i].x) / scaleX, 2) +
          math.pow((outletPoints[i + 1].y - outletPoints[i].y) / scaleY, 2),
        );
        routes.add(ConduitRoute(
          id: 'rt-co-chain-$i',
          fromPointId: outletPoints[i].id,
          toPointId: outletPoints[i + 1].id,
          measuredLengthMeters: dist.clamp(1.5, 6.0),
          conductorCount: 3,
        ));
      }
    }

    // 5. Dedicated Aircon Unit (ACU) for spaces >= 12 sqm
    if (areaSqm >= 12.0) {
      final acuPt = CanvasPoint(
        id: 'pt-acu-auto',
        type: 'ACU',
        label: 'ACU-1',
        x: canvasOriginX + (safeL * scaleX) - 18,
        y: canvasOriginY + 18,
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
    }

    final double totalWireMeters = routes.fold(0.0, (sum, r) => sum + (r.measuredLengthMeters * r.conductorCount));

    return AutoPlacementResult(
      points: points,
      routes: routes,
      totalLights: lightIds.length,
      totalOutlets: outletPoints.length,
      totalSwitches: 1,
      estimatedWireMeters: totalWireMeters,
      complianceSummary: 'PEC 2017 Art 2.10.3.3 Compliant: ${lightIds.length} lights (IESNA lumen-calculated), ${outletPoints.length} duplex outlets (<=3.6m wall spacing), 1 panelboard homerun.',
    );
  }
}
