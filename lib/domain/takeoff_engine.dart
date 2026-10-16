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
    final double totalWireMeters = (totalConduit * 3.0) + wireSpliceAllowance;
    final double rolls = totalWireMeters / rollLengthStandardMeters;

    // Standard support spacing: 1 clamp every 1.5 meters
    final int clamps = (totalConduit / 1.5).ceil() + (points.length * 2);

    // Productivity estimate: 1 meter of rough-in conduit + wire pulling = ~0.25 labor hours
    final double laborHours = (totalConduit * 0.25) + (points.length * 0.5);

    // Costs
    final double materialCost = (pipesCount * pipeUnitPrice) +
        (totalWireMeters * wirePricePerMeter) +
        ((utilityBoxes + octagonalBoxes) * boxUnitPrice) +
        (clamps * 12.0);

    final double laborCost = laborHours * ratePerLaborHour;

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
