// BANAAG Core Domain: Philippine Electrical Code (PEC 2017) Wire Color Coding Engine
// Enforces standard color identification for branch circuits, feeders, switch legs, and grounding.

enum ConductorFunction {
  line1('Line 1 (Phase A / Ungrounded)', 'Black', 0xFF212121, 'Pangunahing live/hot wire para sa single-phase at three-phase distribution.'),
  line2('Line 2 (Phase B / Ungrounded)', 'Red', 0xFFE53935, 'Pangalawang live/hot wire sa 230V 1-phase 2-wire o 3-phase circuits.'),
  line3('Line 3 (Phase C / Ungrounded)', 'Blue', 0xFF1E88E5, 'Pangatlong live wire sa 3-phase industrial/commercial installations.'),
  neutral('Neutral (Grounded Conductor)', 'White / Light Gray', 0xFFECEFF1, 'Mandatory grounded conductor identification alinsunod sa PEC 2.0.1.6.'),
  ground('Equipment Grounding (EGC)', 'Green / Green with Yellow Stripe', 0xFF43A047, 'Proteksyon laban sa ground fault at kuryente alinsunod sa PEC 2.50.6.10.'),
  switchLeg('Switch Leg (Return to Light)', 'Yellow', 0xFFFDD835, 'Wire mula sa saklay/switch papunta sa lighting fixture luminaire.'),
  traveler('3-Way / 4-Way Travelers', 'Orange / Yellow', 0xFFFB8C00, 'Interconnecting lines sa pagitan ng multi-location switches (PEC 4.4.1.2).');

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
      explanation: 'Karaniwang serbisyo sa Pilipinas (Meralco/Coops). Parehong may 115V to ground (total 230V line-to-line), kaya Black (Line 1) at Red (Line 2) ang ginagamit kasama ang Green para sa grounding.',
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
      explanation: 'Kapag ang serbisyo ay may nakalaang Neutral conductor: Black (Line 1 / Hot), White (Neutral), at Green (Ground). Bawal gamitin ang puti o berde bilang ungrounded live conductor.',
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
      explanation: 'Hot feed sa switch (Black), Switch leg patungo sa ilaw (Yellow), at Travelers para sa 3-way/4-way switches (Orange o Blue) upang madaling i-troubleshoot ng electrician.',
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
      explanation: 'Phase A = Black, Phase B = Red, Phase C = Blue, Neutral = White/Gray, Ground = Green. Kinakailangan ang permanent markings sa bawat panelboard.',
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
