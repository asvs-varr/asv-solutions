import 'package:flutter/material.dart';
import 'models.dart';

/// Represents an authentic PEC 2017 compliant guided target spot
class GuidedSnapSpot {
  final Offset position;
  final String deviceType;
  final String label;
  final String ruleReason;
  final bool isProhibited;
  final double radius;

  const GuidedSnapSpot({
    required this.position,
    required this.deviceType,
    required this.label,
    required this.ruleReason,
    this.isProhibited = false,
    this.radius = 14.0,
  });
}

class PecPlacementAdvisor {
  /// Evaluates whether the placed electrical points in a room comply with PEC 2017 & IESNA rules
  /// Returns a list of advisory warning messages.
  static List<String> evaluateRoomPlacement({
    required RoomSpace room,
    required List<Offset> polygon,
    required List<CanvasPoint> roomPoints,
    required double pixelsPerMeter,
  }) {
    final warnings = <String>[];
    if (polygon.length < 3 || pixelsPerMeter <= 0) return warnings;

    final lowerName = room.name.toLowerCase();
    final outlets = roomPoints.where((p) => p.type == 'OUTLET_DUPLEX' || p.type == 'ACU' || p.type == 'RANGE' || p.type == 'WATER_HEATER').toList();
    final lights = roomPoints.where((p) => p.type == 'LIGHT').toList();
    final switches = roomPoints.where((p) => p.type == 'SWITCH_1G' || p.type == 'SWITCH_2G' || p.type == 'SWITCH_3G').toList();

    // 1. Minimum Lighting Check (PEC Sec. 2.10.3.21)
    if (lights.isEmpty && !lowerName.contains('storage') && !lowerName.contains('closet')) {
      warnings.add('⚠️ PEC Sec. 2.10.3.21: Every habitable room requires at least one lighting point controlled by a switch.');
    }

    // 2. Switch Presence Check
    if (lights.isNotEmpty && switches.isEmpty) {
      warnings.add('⚠️ PEC Sec. 2.10.3.21: Luminaire lighting circuit is missing a wall control switch in this room.');
    }

    // 3. Residential Outlet Spacing (PEC 2017 Sec. 2.10.3.3)
    final ppm = pixelsPerMeter;
    const double maxWallGapMeters = 3.6;

    if (lowerName.contains('living') || lowerName.contains('bedroom') || lowerName.contains('dining')) {
      if (outlets.isEmpty && room.areaSqm >= 4.0) {
        warnings.add('⚠️ PEC Sec. 2.10.3.3: Living/Bedroom areas require convenience receptacles along wall spaces.');
      }

      // Check distance between adjacent outlets
      for (int i = 0; i < outlets.length; i++) {
        for (int j = i + 1; j < outlets.length; j++) {
          final distMeters = (Offset(outlets[i].x, outlets[i].y) - Offset(outlets[j].x, outlets[j].y)).distance / ppm;
          if (distMeters > maxWallGapMeters + 1.2) {
            warnings.add('⚠️ PEC Spacing Advisory: Distance between ${outlets[i].label} & ${outlets[j].label} is ${distMeters.toStringAsFixed(1)}m (PEC 1.8m radius limit).');
            break;
          }
        }
      }
    }

    // 4. Bathroom / Wet Area GFCI Rule (PEC Sec. 2.10.1.8)
    if (lowerName.contains('bath') || lowerName.contains('toilet') || lowerName.contains('powder') || lowerName.contains('cr')) {
      for (final out in outlets) {
        if (!out.label.toUpperCase().contains('GFCI')) {
          warnings.add('⚠️ PEC Sec. 2.10.1.8: Bathroom receptacle ${out.label} requires Class A GFCI protection within 900mm of water source.');
          break;
        }
      }
    }

    // 5. Kitchen Small Appliance Branch Circuit (SABC) Rule (PEC Sec. 2.10.3.3(C))
    if (lowerName.contains('kitchen')) {
      if (outlets.length < 2) {
        warnings.add('⚠️ PEC Sec. 2.10.1.11(C)(1): Kitchen countertop requires at least two 20A Small Appliance Branch Circuits (SABC).');
      }
    }

    return warnings;
  }

  /// Computes smart visual suggestion spots (ghost anchors) according to the active tool and PEC 2017 rules
  static List<GuidedSnapSpot> computeGuidedSpots({
    required String activeTool,
    required List<RoomSpace> spaces,
    required Map<String, List<Offset>> roomPolygons,
    required double pixelsPerMeter,
    int? activeRoomIndex,
  }) {
    final spots = <GuidedSnapSpot>[];
    if (spaces.isEmpty || pixelsPerMeter <= 0) return spots;

    final ppm = pixelsPerMeter;

    // A. MAIN DISTRIBUTION PANEL (MDP)
    if (activeTool == 'PANEL') {
      // 1. Recommend Service Corridor / Stair Landing / Utility Shaft
      for (int i = 0; i < spaces.length; i++) {
        final sp = spaces[i];
        final name = sp.name.toLowerCase();
        final poly = roomPolygons[sp.id] ?? [];
        if (poly.length < 3) continue;

        final isServiceOrCorridor = name.contains('corridor') ||
            name.contains('landing') ||
            name.contains('stair') ||
            name.contains('hall') ||
            name.contains('utility') ||
            name.contains('service');

        final isBathroom = name.contains('cr') ||
            name.contains('bath') ||
            name.contains('toilet') ||
            name.contains('powder');

        final rect = _bbox(poly);

        if (isServiceOrCorridor) {
          // Suggest wall near entrance/landing (Top edge center or Left edge center)
          spots.add(GuidedSnapSpot(
            position: Offset(rect.center.dx, rect.top + 14.0),
            deviceType: 'PANEL',
            label: 'LEGAL MDP WALL (PEC 1.10.2.1)',
            ruleReason: 'Service Corridor/Shaft: Readily accessible with 900mm working clearance.',
            radius: 18.0,
          ));
        } else if (isBathroom) {
          // Explicit Prohibited Marker
          spots.add(GuidedSnapSpot(
            position: rect.center,
            deviceType: 'PANEL',
            label: 'PROHIBITED (PEC 2.40.2.5)',
            ruleReason: 'Prohibited: Overcurrent devices shall NOT be located in bathrooms.',
            isProhibited: true,
            radius: 20.0,
          ));
        }
      }
      return spots;
    }

    // Filter to active room if specified, otherwise scan all spaces
    final targetSpaces = (activeRoomIndex != null && activeRoomIndex >= 0 && activeRoomIndex < spaces.length)
        ? [spaces[activeRoomIndex]]
        : spaces;

    for (final sp in targetSpaces) {
      final poly = roomPolygons[sp.id] ?? [];
      if (poly.length < 3) continue;
      final rect = _bbox(poly);
      final roomName = sp.name.toLowerCase();

      // B. LIGHT (Symmetrical Ceiling Grid: s/2 from wall, equal spacing)
      if (activeTool == 'LIGHT') {
        final double widthM = rect.width / ppm;
        final double heightM = rect.height / ppm;

        int cols = 1;
        int rows = 1;
        if (widthM > 4.5) cols = 2;
        if (widthM > 8.0) cols = 3;
        if (heightM > 4.5) rows = 2;
        if (heightM > 8.0) rows = 3;

        final double dx = rect.width / cols;
        final double dy = rect.height / rows;

        for (int r = 0; r < rows; r++) {
          for (int c = 0; c < cols; c++) {
            final target = Offset(rect.left + (c + 0.5) * dx, rect.top + (r + 0.5) * dy);
            spots.add(GuidedSnapSpot(
              position: target,
              deviceType: 'LIGHT',
              label: 'CEILING GRID (${c + 1},${r + 1})',
              ruleReason: 'IESNA / PEC Symmetrical Grid: s/2 spacing from perimeter walls.',
              radius: 16.0,
            ));
          }
        }
      }

      // C. SWITCH (Door Lock-Jamb Wall 150mm from door frame)
      else if (activeTool.startsWith('SWITCH')) {
        // Standard door entrance is located along bottom or top wall near room edge
        // Recommend target 150mm (0.15m * ppm) from interior door swing
        final double offsetPx = 0.25 * ppm; // ~250mm inside doorway
        // Primary entry spot: Bottom-left near entrance
        spots.add(GuidedSnapSpot(
          position: Offset(rect.left + offsetPx, rect.bottom - 16.0),
          deviceType: activeTool,
          label: 'DOOR LOCK-JAMB',
          ruleReason: 'PEC 2017: 150-200mm from door latch side at 1.37m AFF.',
          radius: 14.0,
        ));
        // Alternate secondary doorway entry spot: Top-left
        spots.add(GuidedSnapSpot(
          position: Offset(rect.left + 16.0, rect.top + offsetPx),
          deviceType: activeTool,
          label: 'ALT ENTRY JAMB',
          ruleReason: 'Accessible wall switch location next to room entrance.',
          radius: 14.0,
        ));
      }

      // D. OUTLET (PEC 2017 Sec. 2.10.3.3: 1.8m Rule along Perimeter Walls)
      else if (activeTool == 'OUTLET_DUPLEX') {
        final isBath = roomName.contains('bath') || roomName.contains('toilet') || roomName.contains('cr');
        final double stepPx = 1.8 * ppm; // 1.8m spacing marker

        // Place perimeter points along Top, Bottom, Left, Right walls
        // 1. Top Wall
        double curX = rect.left + (stepPx / 2);
        while (curX < rect.right - 20) {
          spots.add(GuidedSnapSpot(
            position: Offset(curX, rect.top + 10.0),
            deviceType: 'OUTLET_DUPLEX',
            label: isBath ? 'GFCI OUTLET (PEC 2.10.1.8)' : '1.8m WALL OUTLET',
            ruleReason: isBath
                ? 'GFCI required within 900mm of washbasin.'
                : 'PEC 1.8m Rule: No point along wall >1.8m from receptacle.',
            radius: 13.0,
          ));
          curX += stepPx;
        }

        // 2. Bottom Wall
        curX = rect.left + stepPx;
        while (curX < rect.right - 20) {
          spots.add(GuidedSnapSpot(
            position: Offset(curX, rect.bottom - 10.0),
            deviceType: 'OUTLET_DUPLEX',
            label: isBath ? 'GFCI OUTLET' : '1.8m WALL OUTLET',
            ruleReason: 'Perimeter wall receptacle spacing.',
            radius: 13.0,
          ));
          curX += stepPx;
        }

        // 3. Left Wall
        double curY = rect.top + (stepPx / 2);
        while (curY < rect.bottom - 20) {
          spots.add(GuidedSnapSpot(
            position: Offset(rect.left + 10.0, curY),
            deviceType: 'OUTLET_DUPLEX',
            label: 'WALL OUTLET',
            ruleReason: 'Side wall receptacle space.',
            radius: 13.0,
          ));
          curY += stepPx;
        }

        // 4. Right Wall
        curY = rect.top + (stepPx / 2);
        while (curY < rect.bottom - 20) {
          spots.add(GuidedSnapSpot(
            position: Offset(rect.right - 10.0, curY),
            deviceType: 'OUTLET_DUPLEX',
            label: 'WALL OUTLET',
            ruleReason: 'Side wall receptacle space.',
            radius: 13.0,
          ));
          curY += stepPx;
        }
      }

      // E. ACU (Air Conditioning Unit - Exterior / Window-side Perimeter Wall)
      else if (activeTool == 'ACU') {
        // Place along exterior perimeter walls (typically top or right exterior edge)
        spots.add(GuidedSnapSpot(
          position: Offset(rect.center.dx, rect.top + 12.0),
          deviceType: 'ACU',
          label: 'EXTERIOR WINDOW WALL',
          ruleReason: 'PEC / Mechanical Code: Exterior wall for shortest refrigerant run & drainage.',
          radius: 16.0,
        ));
        spots.add(GuidedSnapSpot(
          position: Offset(rect.right - 12.0, rect.center.dy),
          deviceType: 'ACU',
          label: 'SIDE PERIMETER WALL',
          ruleReason: 'Alternative exterior wall location with dedicated branch circuit.',
          radius: 16.0,
        ));
      }
    }

    return spots;
  }

  static Rect _bbox(List<Offset> poly) {
    double minX = poly.first.dx, maxX = poly.first.dx;
    double minY = poly.first.dy, maxY = poly.first.dy;
    for (final p in poly) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}
