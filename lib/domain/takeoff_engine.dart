// BANAAG Takeoff Engine: Computes real-world material quantities from 2D points & conduit routes
// Automatically factors in PEC 3D vertical drops and junction box wire stripping allowances.

import 'models.dart';

class TakeoffResult {
  final double horizontalConduitMeters;
  final double verticalDropMeters;
  final double totalConduitMeters;
  final int totalPvcPipesPcs; // 3 meters per standard PVC pipe in PH
  final double totalThhnWireMeters;
  final double wireRollsCount; // 150 meters per standard roll in PH
  final int utilityBoxesCount;
  final int octagonalBoxesCount;
  final int conduitClampsCount;
  final double estimatedLaborHours;
  final double estimatedMaterialCost;
  final double estimatedLaborCost;

  TakeoffResult({
    required this.horizontalConduitMeters,
    required this.verticalDropMeters,
    required this.totalConduitMeters,
    required this.totalPvcPipesPcs,
    required this.totalThhnWireMeters,
    required this.wireRollsCount,
    required this.utilityBoxesCount,
    required this.octagonalBoxesCount,
    required this.conduitClampsCount,
    required this.estimatedLaborHours,
    required this.estimatedMaterialCost,
    required this.estimatedLaborCost,
  });

  double get grandTotalEstimatedCost => estimatedMaterialCost + estimatedLaborCost;
}

class TakeoffEngine {
  // PEC Standard 3D Vertical Drop Heights (Meters)
  static const double switchDropMeters = 1.2; // Standard 1.4m height from floor minus slab height
  static const double outletDropMeters = 0.3; // Standard convenience outlet height
  static const double panelDropMeters = 1.8; // Panel board homerun drop from ceiling
  static const double boxSpliceAllowanceMeters = 0.15; // 150 mm (6 inches) per box as required by PEC
  static const double pipeLengthStandardMeters = 3.0; // Standard PVC conduit length sold in PH
  static const double rollLengthStandardMeters = 150.0; // Standard THHN wire roll in PH

  /// Compute Takeoff based on placed canvas points and connected conduit routes
  static TakeoffResult calculate({
    required List<CanvasPoint> points,
    required List<ConduitRoute> routes,
    double ratePerLaborHour = 120.0, // Standard helper/electrician blended rate
    double pipeUnitPrice = 95.0, // 20mm PVC pipe (orange or blue)
    double wirePricePerMeter = 28.0, // 3.5mm² THHN copper
    double boxUnitPrice = 25.0, // 2x4 PVC or metal box
  }) {
    double horizontalLength = 0.0;
    double verticalDrops = 0.0;
    double wireSpliceAllowance = 0.0;

    int utilityBoxes = 0;
    int octagonalBoxes = 0;

    // Analyze Points for vertical drops and boxes
    for (final pt in points) {
      switch (pt.type) {
        case 'PANEL':
          verticalDrops += panelDropMeters;
          break;
        case 'SWITCH_1G':
          verticalDrops += switchDropMeters;
          utilityBoxes++;
          wireSpliceAllowance += boxSpliceAllowanceMeters * 2;
          break;
        case 'OUTLET_DUPLEX':
          verticalDrops += outletDropMeters;
          utilityBoxes++;
          wireSpliceAllowance += boxSpliceAllowanceMeters * 3;
          break;
        case 'ACU':
          verticalDrops += 1.8;
          utilityBoxes++;
          wireSpliceAllowance += boxSpliceAllowanceMeters * 3;
          break;
        case 'LIGHT':
        case 'FAN':
          octagonalBoxes++;
          wireSpliceAllowance += boxSpliceAllowanceMeters * 2;
          break;
      }
    }

    // Sum horizontal routes
    for (final r in routes) {
      horizontalLength += r.measuredLengthMeters;
    }

    final double totalConduit = horizontalLength + verticalDrops;
    final int pipesCount = (totalConduit / pipeLengthStandardMeters).ceil();

    // Standard 3-wire system (Phase + Neutral + Ground)
    final double totalWireMeters = double.parse(
      ((totalConduit * 3.0) + wireSpliceAllowance).toStringAsFixed(1),
    );
    final double rolls = totalWireMeters / rollLengthStandardMeters;

    // Verbatim PEC 2017 Sec. 3.52.2.21(A) & Table 3.52.2.21 (Page 231):
    // 15-25 mm Rigid PVC Conduit max support spacing = 900 mm (0.9 m) + fastened within 900 mm of each box/termination
    final int clamps = (totalConduit / 0.9).ceil() + (points.length * 2);

    // Unified Itemized Material & Labor Costs (100% synced with 3-Tab Excel BOM)
    final double materialCost = (totalWireMeters * wirePricePerMeter) +
        (35.0 * 95.0) + // Main Feeder Wire (35m @ PHP 95/m)
        (pipesCount * pipeUnitPrice) +
        (utilityBoxes * boxUnitPrice) +
        (octagonalBoxes * 30.0) +
        (clamps * 6.0) +
        3800.0 + // Main Distribution Panelboard (MDP)
        950.0 + // Copperweld Grounding Rod & Brass Clamp
        650.0; // Miscellaneous Consumables

    final double laborCost = (totalWireMeters * 8.0) +
        (35.0 * 25.0) + // Feeder Wire Pulling Labor
        (pipesCount * 35.0) +
        (utilityBoxes * 15.0) +
        (octagonalBoxes * 20.0) +
        (clamps * 4.0) +
        850.0 + // Panelboard Mounting & Termination
        400.0 + // Grounding Electrode Driving & Bonding
        200.0; // Consumables Application

    final double laborHours = laborCost / ratePerLaborHour;

    return TakeoffResult(
      horizontalConduitMeters: horizontalLength,
      verticalDropMeters: verticalDrops,
      totalConduitMeters: totalConduit,
      totalPvcPipesPcs: pipesCount,
      totalThhnWireMeters: totalWireMeters,
      wireRollsCount: rolls,
      utilityBoxesCount: utilityBoxes,
      octagonalBoxesCount: octagonalBoxes,
      conduitClampsCount: clamps,
      estimatedLaborHours: laborHours,
      estimatedMaterialCost: materialCost,
      estimatedLaborCost: laborCost,
    );
  }
}
