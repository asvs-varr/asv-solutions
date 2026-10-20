// BANAAG Core Domain: Philippine Electrical Code (PEC 2017) Wire Color Coding Engine
// Enforces standard color identification for branch circuits, feeders, switch legs, and grounding.

enum ConductorFunction {
  line1('Line 1 (Phase A / Ungrounded)', 'Black', 0xFF212121, 'Primary ungrounded phase conductor for single-phase and three-phase distribution.'),
  line2('Line 2 (Phase B / Ungrounded)', 'Red', 0xFFE53935, 'Secondary ungrounded phase conductor for 230V 1-phase 2-wire or 3-phase circuits.'),
  line3('Line 3 (Phase C / Ungrounded)', 'Blue', 0xFF1E88E5, 'Tertiary ungrounded phase conductor for 3-phase commercial and industrial systems.'),
  neutral('Neutral (Grounded Conductor)', 'White / Light Gray', 0xFFECEFF1, 'Mandatory grounded conductor identification in compliance with PEC Art 2.0.1.6.'),
  ground('Equipment Grounding Conductor (EGC)', 'Green / Green with Yellow Stripe', 0xFF43A047, 'Equipment grounding protection against ground-fault shock hazard per PEC Art 2.50.6.10.'),
  switchLeg('Switch Leg (Return to Luminaire)', 'Yellow', 0xFFFDD835, 'Switched phase conductor routed from control switch to luminaire ballast/driver.'),
  traveler('3-Way / 4-Way Travelers', 'Orange / Yellow', 0xFFFB8C00, 'Interconnecting switch travelers between multi-location control devices (PEC Art 4.4.1.2).');

  final String label;
  final String colorName;
  final int colorHex;
  final String description;
  const ConductorFunction(this.label, this.colorName, this.colorHex, this.description);
}

class PecColorCodeRule {
  final String circuitType;
  final String systemVoltage;
  final List<ConductorFunction> conductors;
  final String pecCitation;
  final String explanation;

  const PecColorCodeRule({
    required this.circuitType,
    required this.systemVoltage,
    required this.conductors,
    required this.pecCitation,
    required this.explanation,
  });
}

class WiringColorCodingEngine {
  WiringColorCodingEngine._();

  static const List<PecColorCodeRule> standardRules = [
    PecColorCodeRule(
      circuitType: '230V 1-Phase 2-Wire (Meralco / Standard Residential)',
      systemVoltage: '230V AC, 2-Wire + Ground',
      conductors: [
        ConductorFunction.line1,
        ConductorFunction.line2,
        ConductorFunction.ground,
      ],
      pecCitation: 'PEC 2017 Art 2.0.1.6 & Art 2.50.6.10',
      explanation: 'Standard Philippine distribution system (Meralco/Electric Cooperatives). Both legs carry ~115V to ground (230V line-to-line), designated Black (Line 1) and Red (Line 2) with Green Equipment Grounding Conductor.',
    ),
    PecColorCodeRule(
      circuitType: '230V 1-Phase with Neutral (Modern Distribution Transformers)',
      systemVoltage: '230V AC Line-to-Neutral + Ground',
      conductors: [
        ConductorFunction.line1,
        ConductorFunction.neutral,
        ConductorFunction.ground,
      ],
      pecCitation: 'PEC 2017 Art 2.0.1.6 & Art 3.10.1.12',
      explanation: 'For systems supplied with a grounded neutral conductor: Black (Line 1 / Hot), White (Neutral), and Green (Ground). White or green insulation is prohibited on ungrounded phase conductors.',
    ),
    PecColorCodeRule(
      circuitType: 'Lighting Branch & Switch Control Loop',
      systemVoltage: '230V AC Lighting Circuit',
      conductors: [
        ConductorFunction.line1,
        ConductorFunction.switchLeg,
        ConductorFunction.traveler,
        ConductorFunction.ground,
      ],
      pecCitation: 'PEC 2017 Art 4.4.1.2 & Art 2.10.1.5',
      explanation: 'Continuous ungrounded phase feed to switch (Black), switch leg to luminaire load (Yellow), and travelers for 3-way/4-way switching circuits (Orange/Blue) for field maintenance safety.',
    ),
    PecColorCodeRule(
      circuitType: '230V/400V 3-Phase 4-Wire Wye Commercial/Industrial',
      systemVoltage: '230/400V 3-Phase + Neutral + Ground',
      conductors: [
        ConductorFunction.line1,
        ConductorFunction.line2,
        ConductorFunction.line3,
        ConductorFunction.neutral,
        ConductorFunction.ground,
      ],
      pecCitation: 'PEC 2017 Art 2.10.1.5(C) & Table 3.10.2.6',
      explanation: 'Phase A = Black, Phase B = Red, Phase C = Blue, Neutral = White/Gray, Ground = Green. Permanent phase marking is mandatory at all panelboards and disconnects.',
    ),
  ];

  /// Generate Bill of Materials Wire Color Breakdown
  /// Computes approximate length per color for an installation
  static Map<String, double> computeColorBOM({
    required double totalConduitLengthMeters,
    required bool hasGrounding,
    bool is3WayLighting = false,
  }) {
    // Standard 2-wire run has Line 1 and Line 2 (or Line + Neutral)
    final double l1Length = totalConduitLengthMeters * 1.10; // +10% terminal allowance
    final double l2Length = totalConduitLengthMeters * 1.10;
    final double groundLength = hasGrounding ? totalConduitLengthMeters * 1.05 : 0.0;
    final double switchLegLength = is3WayLighting ? totalConduitLengthMeters * 0.40 : totalConduitLengthMeters * 0.20;

    return {
      'Black (Line 1)': l1Length,
      'Red (Line 2)': l2Length,
      if (hasGrounding) 'Green (Ground)': groundLength,
      if (switchLegLength > 0) 'Yellow (Switch Leg)': switchLegLength,
    };
  }
}
