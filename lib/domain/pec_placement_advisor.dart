import 'package:flutter/material.dart';
import 'models.dart';

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
    // No point along floor line shall be more than 1,800 mm (1.8m) from an outlet.
    // That means maximum distance between outlets along perimeter walls is 3.6m.
    final ppm = pixelsPerMeter;
    final double maxWallGapMeters = 3.6;

    if (lowerName.contains('living') || lowerName.contains('bedroom') || lowerName.contains('dining')) {
      if (outlets.isEmpty && room.areaSqm >= 4.0) {
        warnings.add('⚠️ PEC Sec. 2.10.3.3: Living/Bedroom areas require convenience receptacles along wall spaces.');
      }

      // Check distance between adjacent outlets
      for (int i = 0; i < outlets.length; i++) {
        for (int j = i + 1; j < outlets.length; j++) {
          final distMeters = (Offset(outlets[i].x, outlets[i].y) - Offset(outlets[j].x, outlets[j].y)).distance / ppm;
          if (distMeters > maxWallGapMeters + 1.2) {
            // Only warn if distance is significantly excessive
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
}
