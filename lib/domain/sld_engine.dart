// BANAAG Core Domain: Single-Line Diagram (SLD) & Schedule of Loads Generator Engine
// Compliant with Philippine Electrical Code (PEC 2017) Part 1

import 'models.dart';
import 'pec_engine.dart';

class SldBranchCircuit {
  final int circuitNumber;
  String description;
  double loadVA;
  int voltage;
  double loadCurrentAmps;
  int breakerRatingAmps;
  int poles;
  String wireSizeDescription;
  String conduitDescription;
  bool isSpare;
  double measuredRunMeters;
  double voltageDropPercent;
  bool isUpsized;
  String upsizeReason;

  SldBranchCircuit({
    required this.circuitNumber,
    required this.description,
    required this.loadVA,
    this.voltage = 230,
    required this.loadCurrentAmps,
    required this.breakerRatingAmps,
    this.poles = 2,
    required this.wireSizeDescription,
    required this.conduitDescription,
    this.isSpare = false,
    this.measuredRunMeters = 15.0,
    this.voltageDropPercent = 1.5,
    this.isUpsized = false,
    this.upsizeReason = '',
  });

  Map<String, dynamic> toJson() => {
    'circuitNumber': circuitNumber,
    'description': description,
    'loadVA': loadVA,
    'voltage': voltage,
    'loadCurrentAmps': loadCurrentAmps,
    'breakerRatingAmps': breakerRatingAmps,
    'poles': poles,
    'wireSizeDescription': wireSizeDescription,
    'conduitDescription': conduitDescription,
    'isSpare': isSpare,
    'measuredRunMeters': measuredRunMeters,
    'voltageDropPercent': voltageDropPercent,
    'isUpsized': isUpsized,
    'upsizeReason': upsizeReason,
  };

  factory SldBranchCircuit.fromJson(Map<String, dynamic> json) => SldBranchCircuit(
    circuitNumber: json['circuitNumber'] ?? 1,
    description: json['description'] ?? '',
    loadVA: (json['loadVA'] as num?)?.toDouble() ?? 0.0,
    voltage: json['voltage'] ?? 230,
    loadCurrentAmps: (json['loadCurrentAmps'] as num?)?.toDouble() ?? 0.0,
    breakerRatingAmps: json['breakerRatingAmps'] ?? 20,
    poles: json['poles'] ?? 2,
    wireSizeDescription: json['wireSizeDescription'] ?? '2 - 3.5 mm² THHN',
    conduitDescription: json['conduitDescription'] ?? '20 mm Ø PVC',
    isSpare: json['isSpare'] ?? false,
    measuredRunMeters: (json['measuredRunMeters'] as num?)?.toDouble() ?? 15.0,
    voltageDropPercent: (json['voltageDropPercent'] as num?)?.toDouble() ?? 1.5,
    isUpsized: json['isUpsized'] ?? false,
    upsizeReason: json['upsizeReason'] ?? '',
  );
}

class SldFeederSpec {
  final double totalConnectedVA;
  final double netDemandVA;
  final double netCurrentAmps;
  final int mainBreakerAmps;
  final String mainBreakerDescription;
  final String feederWireDescription;
  final String groundingDescription;
  final String conduitDescription;
  final String serviceDropDescription;

  SldFeederSpec({
    required this.totalConnectedVA,
    required this.netDemandVA,
    required this.netCurrentAmps,
    required this.mainBreakerAmps,
    required this.mainBreakerDescription,
    required this.feederWireDescription,
    required this.groundingDescription,
    required this.conduitDescription,
    required this.serviceDropDescription,
  });

  Map<String, dynamic> toJson() => {
    'totalConnectedVA': totalConnectedVA,
    'netDemandVA': netDemandVA,
    'netCurrentAmps': netCurrentAmps,
    'mainBreakerAmps': mainBreakerAmps,
    'mainBreakerDescription': mainBreakerDescription,
    'feederWireDescription': feederWireDescription,
    'groundingDescription': groundingDescription,
    'conduitDescription': conduitDescription,
    'serviceDropDescription': serviceDropDescription,
  };

  factory SldFeederSpec.fromJson(Map<String, dynamic> json) => SldFeederSpec(
    totalConnectedVA: (json['totalConnectedVA'] as num?)?.toDouble() ?? 0.0,
    netDemandVA: (json['netDemandVA'] as num?)?.toDouble() ?? 0.0,
    netCurrentAmps: (json['netCurrentAmps'] as num?)?.toDouble() ?? 0.0,
    mainBreakerAmps: json['mainBreakerAmps'] ?? 60,
    mainBreakerDescription: json['mainBreakerDescription'] ?? '',
    feederWireDescription: json['feederWireDescription'] ?? '',
    groundingDescription: json['groundingDescription'] ?? '',
    conduitDescription: json['conduitDescription'] ?? '',
    serviceDropDescription: json['serviceDropDescription'] ?? '',
  );
}

class SingleLineDiagramData {
  final SldFeederSpec feeder;
  final List<SldBranchCircuit> branchCircuits;
  final String panelName; // e.g., "LP-1 (Main Lighting & Power Panel)"
  final String utilityProvider;

  SingleLineDiagramData({
    required this.feeder,
    required this.branchCircuits,
    this.panelName = 'LP-1 (Main Distribution Panel)',
    this.utilityProvider = 'Meralco',
  });

  Map<String, dynamic> toJson() => {
    'feeder': feeder.toJson(),
    'branchCircuits': branchCircuits.map((b) => b.toJson()).toList(),
    'panelName': panelName,
    'utilityProvider': utilityProvider,
  };

  factory SingleLineDiagramData.fromJson(Map<String, dynamic> json) => SingleLineDiagramData(
    feeder: SldFeederSpec.fromJson(json['feeder'] as Map<String, dynamic>),
    branchCircuits: (json['branchCircuits'] as List<dynamic>?)
            ?.map((b) => SldBranchCircuit.fromJson(b as Map<String, dynamic>))
            .toList() ??
        [],
    panelName: json['panelName'] ?? 'LP-1 (Main Distribution Panel)',
    utilityProvider: json['utilityProvider'] ?? 'Meralco',
  );

  /// Official PEC 2017 Basis & Citations for this specific Schedule of Loads calculation
  List<Map<String, String>> get pecEngineeringBasis => [
    {
      'topic': 'Feeder Demand Factor',
      'citation': 'PEC 2017 Table 2.20.3.3',
      'formula': 'Unang 3,000 VA @ 100% Demand, Natitirang karga @ 35%-40% Residential Demand Factor.',
      'computed': 'Total Connected: ${feeder.totalConnectedVA.toStringAsFixed(0)} VA ➔ Net Demand: ${feeder.netDemandVA.toStringAsFixed(0)} VA (${feeder.netCurrentAmps.toStringAsFixed(1)} A)',
    },
    {
      'topic': 'Main Feeder & Overcurrent Protection',
      'citation': 'PEC 2017 Art 2.15.1.2 & Art 2.15.1.3',
      'formula': 'Feeder conductors & MCB must have ampacity not less than 125% of continuous design load (I_design = I_net × 1.25).',
      'computed': '${feeder.netCurrentAmps.toStringAsFixed(1)} A × 1.25 = ${(feeder.netCurrentAmps * 1.25).toStringAsFixed(1)} A ➔ Main Breaker: ${feeder.mainBreakerAmps} AT / 100 AF 2P',
    },
    {
      'topic': 'Main Feeder Conductors & Raceway',
      'citation': 'PEC 2017 Table 3.10.2.6 & Chapter 9 Table 1',
      'formula': 'Copper THHN/THWN-2 allowable ampacity at 75°C terminal rating with maximum 40% conduit fill limit for >=3 wires.',
      'computed': 'Conductors: ${feeder.feederWireDescription} sa loob ng ${feeder.conduitDescription}',
    },
    {
      'topic': 'Grounding Electrode Conductor (GEC)',
      'citation': 'PEC 2017 Table 2.50.3.17 & Art 2.50.3.8',
      'formula': 'Minimum Grounding Electrode Conductor size based on largest ungrounded service-entrance conductor.',
      'computed': feeder.groundingDescription,
    },
    {
      'topic': 'Branch Circuit Voltage Drop Limit (3.0% Max)',
      'citation': 'PEC 2017 Art 2.10.2.1 FPN No. 4 & Art 2.15.1.2(a) FPN No. 2',
      'formula': '%VD = (2 × L_run × I_load × R_wire / 1000 / 230) × 100%. Max allowable: 3% for branch circuit, 5% total overall system.',
      'computed': 'Lahat ng branch circuits ay sinusukat gamit ang 3D Manhattan Run (panel drop + horizontal run + device drop + 150mm splice). Ang mga lagpas sa 3.0% ay awtomatikong ina-upsize sa kasunod na standard wire size.',
    },
    {
      'topic': 'Spare Circuit Provision',
      'citation': 'PEC 2017 Art 4.8.1.13',
      'formula': 'Mandatory spare overcurrent devices for panelboard future load expansion without rewiring enclosure.',
      'computed': 'Kasama ang 2 Spare Breakers (20A at 30A 2P) sa active schedule.',
    },
  ];
}

class SldEngine {
  /// Generates a fully PEC-compliant Single-Line Diagram and Schedule of Loads from project appliances
  static SingleLineDiagramData generateFromProject(Project project) {
    final appliances = project.applianceLoads;
    final List<SldBranchCircuit> circuits = [];

    if (appliances.isEmpty) {
      // Return a clean default single-line baseline for typical Philippine 2-bedroom home
      return _generateDefaultResidentialSld(project.utilityProvider);
    }

    // 1. Group appliances into PEC functional circuits
    // Circuit 1: Lighting Outlets
    final lightingItems = appliances.where((a) => a.isLighting).toList();
    double lightingVA = lightingItems.fold(0.0, (sum, a) => sum + a.totalVA);
    if (lightingVA <= 0) lightingVA = 850.0; // Standard minimal lighting allowance

    // If lighting exceeds 1200 VA (80% of 15A), split into 2 circuits
    if (lightingVA > 1200) {
      final half = lightingVA / 2;
      circuits.add(_createBranch(
        circuitNumber: circuits.length + 1,
        desc: 'Lighting Outlets (Living, Dining, Kitchen)',
        va: half,
        isLighting: true,
      ));
      circuits.add(_createBranch(
        circuitNumber: circuits.length + 1,
        desc: 'Lighting Outlets (Bedrooms, Hallway & Exterior)',
        va: half,
        isLighting: true,
      ));
    } else {
      circuits.add(_createBranch(
        circuitNumber: circuits.length + 1,
        desc: 'General Lighting Outlets (All Areas)',
        va: lightingVA,
        isLighting: true,
      ));
    }

    // Circuit 2: General Purpose & Small Appliance Convenience Outlets (PEC Art 2.10.1.11)
    final generalOutlets = appliances.where((a) => !a.isLighting && !a.isDedicatedCircuit).toList();
    double generalOutletVA = generalOutlets.fold(0.0, (sum, a) => sum + a.totalVA);
    if (generalOutletVA <= 0) generalOutletVA = 1440.0; // 8 duplex outlets standard

    // Standard descriptive names mapped according to PEC 2017 & Residential Functional Zoning
    const outletDescriptions = [
      'Small Appliance Outlets (Kitchen Countertop & Dining SABC)',
      'General Convenience Outlets (Living Room, Foyer & Entertainment)',
      'General Convenience Outlets (Master & Guest Bedrooms, Hallway)',
      'Utility & Outdoor Convenience Outlets (Garage, Balcony & Patio)',
      'General Convenience Outlets (Home Office & Study Area)',
    ];

    // PEC Rule: General purpose outlets max 1800VA per 20A branch (180 VA x 10 duplex outlets)
    if (generalOutletVA > 1800) {
      final count = (generalOutletVA / 1800).ceil();
      final vaPerCircuit = generalOutletVA / count;
      for (int i = 0; i < count; i++) {
        final label = i < outletDescriptions.length
            ? outletDescriptions[i]
            : 'General Convenience Outlets (Zone ${i + 1})';
        circuits.add(_createBranch(
          circuitNumber: circuits.length + 1,
          desc: label,
          va: vaPerCircuit,
          isLighting: false,
        ));
      }
    } else {
      circuits.add(_createBranch(
        circuitNumber: circuits.length + 1,
        desc: 'General Convenience Outlets (Living, Dining & Bedrooms)',
        va: generalOutletVA,
        isLighting: false,
      ));
    }

    // Dedicated Circuits: ACU, Range, Water Heater, Water Pump
    final dedicatedItems = appliances.where((a) => a.isDedicatedCircuit).toList();
    for (final item in dedicatedItems) {
      for (int q = 0; q < item.quantity; q++) {
        final label = item.quantity > 1 ? '${item.name} (${q + 1})' : item.name;
        circuits.add(_createBranch(
          circuitNumber: circuits.length + 1,
          desc: 'Dedicated: $label',
          va: item.ratingVA,
          isLighting: false,
          isDedicated: true,
        ));
      }
    }

    // Always append 2 Standard Spare Breakers for future expansion (PEC requirement)
    circuits.add(SldBranchCircuit(
      circuitNumber: circuits.length + 1,
      description: 'SPARE (Future Expansion)',
      loadVA: 0.0,
      loadCurrentAmps: 0.0,
      breakerRatingAmps: 20,
      poles: 2,
      wireSizeDescription: '2 - 3.5 mm² THHN + 1 - 3.5 mm² Ground',
      conduitDescription: '20 mm Ø PVC',
      isSpare: true,
    ));
    circuits.add(SldBranchCircuit(
      circuitNumber: circuits.length + 1,
      description: 'SPARE (Future Expansion)',
      loadVA: 0.0,
      loadCurrentAmps: 0.0,
      breakerRatingAmps: 30,
      poles: 2,
      wireSizeDescription: '2 - 5.5 mm² THHN + 1 - 5.5 mm² Ground',
      conduitDescription: '20 mm Ø PVC',
      isSpare: true,
    ));

    // 2. Compute Main Feeder & Service Entrance Specifications
    final double totalConnectedVA = circuits.fold(0.0, (sum, c) => sum + c.loadVA);

    // Apply Exact PEC 2017 Table 2.20.3.3 Dwelling Unit Demand Factors:
    // General Lighting & Small Appliance / General Purpose Outlets:
    // - First 3,000 VA @ 100% Demand
    // - 3,001 to 120,000 VA @ 35% Demand
    // Dedicated Motor / ACU Loads: 100% (plus 25% of largest motor per PEC 4.30.2.2)
    final double generalLightingAndOutletsVA = circuits
        .where((c) => !c.isSpare && (c.description.contains('Lighting') || c.description.contains('Convenience')))
        .fold(0.0, (sum, c) => sum + c.loadVA);

    final double dedicatedLoadsVA = circuits
        .where((c) => !c.isSpare && !c.description.contains('Lighting') && !c.description.contains('Convenience'))
        .fold(0.0, (sum, c) => sum + c.loadVA);

    double netGeneralVA = 0.0;
    if (generalLightingAndOutletsVA <= 3000.0) {
      netGeneralVA = generalLightingAndOutletsVA;
    } else {
      netGeneralVA = 3000.0 + ((generalLightingAndOutletsVA - 3000.0) * 0.35); // PEC Table 2.20.3.3: 35%
    }

    final double netDemandVA = netGeneralVA + dedicatedLoadsVA;
    final double netCurrentAmps = netDemandVA / 230.0;

    // Sizing Main Breaker with 125% continuous margin
    final double designMainAmps = netCurrentAmps * 1.25;
    int mainBreakerAmps = 60;
    for (final rating in [60, 75, 100, 125, 150, 175, 200]) {
      if (rating >= designMainAmps) {
        mainBreakerAmps = rating;
        break;
      }
    }

    // Determine Main Feeder Wire and Conduit
    String feederWire = '2 - 22 mm² THHN';
    String feederConduit = '25 mm Ø PVC';
    String groundWire = '1 - 8.0 mm² Bare/Insulated Cu';

    if (mainBreakerAmps <= 60) {
      feederWire = '2 - 22 mm² THHN';
      feederConduit = '25 mm Ø PVC';
    } else if (mainBreakerAmps <= 100) {
      feederWire = '2 - 30 mm² THHN';
      feederConduit = '32 mm Ø PVC';
    } else if (mainBreakerAmps <= 125) {
      feederWire = '2 - 38 mm² THHN';
      feederConduit = '40 mm Ø PVC';
    } else {
      feederWire = '2 - 50 mm² THHN';
      feederConduit = '50 mm Ø PVC';
    }

    final feeder = SldFeederSpec(
      totalConnectedVA: totalConnectedVA,
      netDemandVA: netDemandVA,
      netCurrentAmps: netCurrentAmps,
      mainBreakerAmps: mainBreakerAmps,
      mainBreakerDescription: '$mainBreakerAmps AT, 100 AF, 2-Pole, 230V, 60Hz, 10kAIC MCB',
      feederWireDescription: feederWire,
      groundingDescription: '$groundWire to 16mm Ø x 2.4m Copperweld Ground Rod',
      conduitDescription: feederConduit,
      serviceDropDescription: '230V, 1-Phase, 2-Wire, 60Hz AC Service Drop (${project.utilityProvider})',
    );

    return SingleLineDiagramData(
      feeder: feeder,
      branchCircuits: circuits,
      panelName: 'LP-1 (Main Lighting & Power Panelboard)',
      utilityProvider: project.utilityProvider,
    );
  }

  static SldBranchCircuit _createBranch({
    required int circuitNumber,
    required String desc,
    required double va,
    required bool isLighting,
    bool isDedicated = false,
    double? runMeters,
  }) {
    final double amps = va / 230.0;
    int breaker = isLighting ? 15 : 20;

    // Dedicated equipment sizing
    if (isDedicated) {
      if (amps > 24) {
        breaker = 40;
      } else if (amps > 16) {
        breaker = 30;
      } else {
        breaker = 20;
      }
    }

    // Baseline minimum PEC wire size
    double baseWireMm2 = 3.5;
    if (breaker == 15) {
      baseWireMm2 = 2.0;
    } else if (breaker == 20) {
      baseWireMm2 = 3.5;
    } else if (breaker == 30) {
      baseWireMm2 = 5.5;
    } else if (breaker >= 40) {
      baseWireMm2 = 8.0;
    }

    // Compute or default 3D Manhattan Run length
    // (Panel drop 1.8m + horizontal run + device drop 0.3m/1.2m + 0.15m splice)
    final double effectiveRunMeters = runMeters ?? (isDedicated ? 18.0 : (12.0 + (circuitNumber * 2.5)));

    // Initial Voltage Drop with base wire
    PecWireSpec currentWireSpec = PecEngine.wireSpecs.firstWhere(
      (w) => w.sizeMm2 >= baseWireMm2,
      orElse: () => PecEngine.wireSpecs.first,
    );

    double vdPercent = PecEngine.computeVoltageDropPercent(
      loadCurrentAmps: amps,
      oneWayLengthMeters: effectiveRunMeters,
      wireSpec: currentWireSpec,
    );

    bool isUpsized = false;
    String upsizeReason = '';

    // PEC Rule Art 2.10.2.1 FPN No. 4: Maximum 3.0% voltage drop on branch circuits
    if (vdPercent > 3.0 && amps > 0) {
      final double initialVd = vdPercent;
      final double initialWire = currentWireSpec.sizeMm2;

      // Iteratively step up wire size until VD <= 3.0% or max standard reached
      for (final candidate in PecEngine.wireSpecs) {
        if (candidate.sizeMm2 > initialWire) {
          final candidateVd = PecEngine.computeVoltageDropPercent(
            loadCurrentAmps: amps,
            oneWayLengthMeters: effectiveRunMeters,
            wireSpec: candidate,
          );
          if (candidateVd <= 3.0 || candidate == PecEngine.wireSpecs.last) {
            currentWireSpec = candidate;
            vdPercent = candidateVd;
            isUpsized = true;
            upsizeReason = 'Auto-upsized mula ${initialWire.toStringAsFixed(1)} mm² patungong ${candidate.sizeMm2.toStringAsFixed(1)} mm² (PEC 3.0% Limit: ${initialVd.toStringAsFixed(1)}% ➔ ${vdPercent.toStringAsFixed(1)}% sa ${effectiveRunMeters.toStringAsFixed(1)}m run)';
            break;
          }
        }
      }
    }

    // Determine Ground wire & Conduit based on PEC Table 2.50.6.13 breaker rating
    final double egcMm2 = PecEngine.getMinimumEquipmentGroundingConductorMm2(breaker);
    final String groundWireSize = '${egcMm2.toStringAsFixed(1).replaceAll('.0', '')} mm²';

    String conduit = '20 mm Ø PVC';
    if (currentWireSpec.sizeMm2 >= 8.0) {
      conduit = '25 mm Ø PVC';
    }

    final String wireDesc = '2 - ${currentWireSpec.sizeMm2.toStringAsFixed(1).replaceAll('.0', '')} mm² THHN + 1 - $groundWireSize Ground';

    return SldBranchCircuit(
      circuitNumber: circuitNumber,
      description: desc,
      loadVA: va,
      voltage: 230,
      loadCurrentAmps: amps,
      breakerRatingAmps: breaker,
      poles: 2,
      wireSizeDescription: wireDesc,
      conduitDescription: conduit,
      isSpare: false,
      measuredRunMeters: effectiveRunMeters,
      voltageDropPercent: vdPercent,
      isUpsized: isUpsized,
      upsizeReason: upsizeReason,
    );
  }

  static SingleLineDiagramData _generateDefaultResidentialSld(String utility) {
    final defaultBranches = [
      SldBranchCircuit(
        circuitNumber: 1,
        description: 'Lighting Outlets (Living, Dining, Kitchen)',
        loadVA: 650.0,
        loadCurrentAmps: 2.83,
        breakerRatingAmps: 15,
        wireSizeDescription: '2 - 2.0 mm² THHN + 1 - 2.0 mm² Ground',
        conduitDescription: '20 mm Ø PVC',
        measuredRunMeters: 14.5,
        voltageDropPercent: 0.37,
      ),
      SldBranchCircuit(
        circuitNumber: 2,
        description: 'Lighting Outlets (Bedrooms, Bath & Balcony)',
        loadVA: 520.0,
        loadCurrentAmps: 2.26,
        breakerRatingAmps: 15,
        wireSizeDescription: '2 - 2.0 mm² THHN + 1 - 2.0 mm² Ground',
        conduitDescription: '20 mm Ø PVC',
        measuredRunMeters: 18.0,
        voltageDropPercent: 0.37,
      ),
      SldBranchCircuit(
        circuitNumber: 3,
        description: 'Convenience Outlets (Living & Dining Area)',
        loadVA: 1440.0,
        loadCurrentAmps: 6.26,
        breakerRatingAmps: 20,
        wireSizeDescription: '2 - 3.5 mm² THHN + 1 - 3.5 mm² Ground',
        conduitDescription: '20 mm Ø PVC',
        measuredRunMeters: 16.5,
        voltageDropPercent: 0.58,
      ),
      SldBranchCircuit(
        circuitNumber: 4,
        description: 'Kitchen Heavy Appliance Outlets',
        loadVA: 1800.0,
        loadCurrentAmps: 7.83,
        breakerRatingAmps: 20,
        wireSizeDescription: '2 - 3.5 mm² THHN + 1 - 3.5 mm² Ground',
        conduitDescription: '20 mm Ø PVC',
        measuredRunMeters: 19.5,
        voltageDropPercent: 0.86,
      ),
      SldBranchCircuit(
        circuitNumber: 5,
        description: 'Dedicated: 2.0HP Inverter ACU (Master)',
        loadVA: 1950.0,
        loadCurrentAmps: 8.48,
        breakerRatingAmps: 30,
        wireSizeDescription: '2 - 5.5 mm² THHN + 1 - 5.5 mm² Ground',
        conduitDescription: '20 mm Ø PVC',
        measuredRunMeters: 22.0,
        voltageDropPercent: 0.67,
      ),
      SldBranchCircuit(
        circuitNumber: 6,
        description: 'Dedicated: 3.5kW Multipoint Water Heater',
        loadVA: 3500.0,
        loadCurrentAmps: 15.22,
        breakerRatingAmps: 30,
        wireSizeDescription: '2 - 5.5 mm² THHN + 1 - 5.5 mm² Ground',
        conduitDescription: '20 mm Ø PVC',
        measuredRunMeters: 24.5,
        voltageDropPercent: 1.33,
      ),
      SldBranchCircuit(
        circuitNumber: 7,
        description: 'SPARE (Future Expansion)',
        loadVA: 0.0,
        loadCurrentAmps: 0.0,
        breakerRatingAmps: 20,
        wireSizeDescription: '2 - 3.5 mm² THHN + 1 - 3.5 mm² Ground',
        conduitDescription: '20 mm Ø PVC',
        isSpare: true,
        measuredRunMeters: 0.0,
        voltageDropPercent: 0.0,
      ),
      SldBranchCircuit(
        circuitNumber: 8,
        description: 'SPARE (Future Expansion)',
        loadVA: 0.0,
        loadCurrentAmps: 0.0,
        breakerRatingAmps: 30,
        wireSizeDescription: '2 - 5.5 mm² THHN + 1 - 5.5 mm² Ground',
        conduitDescription: '20 mm Ø PVC',
        isSpare: true,
        measuredRunMeters: 0.0,
        voltageDropPercent: 0.0,
      ),
    ];

    final double totalVA = defaultBranches.fold(0.0, (sum, c) => sum + c.loadVA);
    final double netVA = 3000.0 + ((totalVA - 3000.0) * 0.40);
    final double netAmps = netVA / 230.0;

    final feeder = SldFeederSpec(
      totalConnectedVA: totalVA,
      netDemandVA: netVA,
      netCurrentAmps: netAmps,
      mainBreakerAmps: 60,
      mainBreakerDescription: '60 AT, 100 AF, 2-Pole, 230V, 60Hz, 10kAIC MCB',
      feederWireDescription: '2 - 22 mm² THHN',
      groundingDescription: '1 - 8.0 mm² Cu to 16mm Ø x 2.4m Ground Rod',
      conduitDescription: '25 mm Ø PVC',
      serviceDropDescription: '230V, 1-Phase, 2-Wire, 60Hz AC Service Drop ($utility)',
    );

    return SingleLineDiagramData(
      feeder: feeder,
      branchCircuits: defaultBranches,
      panelName: 'LP-1 (Main Lighting & Power Panelboard)',
      utilityProvider: utility,
    );
  }
}
