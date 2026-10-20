// BANAAG Institutional Building Presets & Multi-Panel Engineering Engine
// Tailored for Two-Storey Academic & Tech-Voc Buildings
// (e.g. San Lorenzo Ruiz Technological College: Rooms 1-4, Faculty Office, Demo Room, Welding Area)
// Compliant with PEC 2017 Part 1 & IESNA Educational Standards.

import 'models.dart';
import 'sld_engine.dart';

class InstitutionalBuildingPreset {
  final String title;
  final String institutionName;
  final String location;
  final List<RoomSpace> firstFloorSpaces;
  final List<RoomSpace> secondFloorSpaces;
  final List<ApplianceItem> firstFloorAppliances;
  final List<ApplianceItem> secondFloorAppliances;

  const InstitutionalBuildingPreset({
    required this.title,
    required this.institutionName,
    required this.location,
    required this.firstFloorSpaces,
    required this.secondFloorSpaces,
    required this.firstFloorAppliances,
    required this.secondFloorAppliances,
  });

  double get totalWidthMeters => 21.60;
  double get totalHeightMeters => 19.48;

  /// Official Preset for San Lorenzo Ruiz Technological College
  static InstitutionalBuildingPreset sanLorenzoRuizCollege() {
    return InstitutionalBuildingPreset(
      title: 'Two-Storey Institutional Building (San Lorenzo Ruiz Tech College)',
      institutionName: 'SAN LORENZO RUIZ TECHNOLOGICAL COLLEGE',
      location: 'P-3, Brgy. Matacong, San Lorenzo Ruiz, Camarines Norte',
      firstFloorSpaces: [
        RoomSpace(id: 'sp-fl1-demo', name: 'Demonstration Room', areaSqm: 38.0, ceilingHeight: 3.0),
        RoomSpace(id: 'sp-fl1-weld', name: 'Welding & Fab Shop Area', areaSqm: 29.0, ceilingHeight: 3.2),
        RoomSpace(id: 'sp-fl1-rm1', name: 'Classroom: Room 1', areaSqm: 46.0, ceilingHeight: 2.8),
        RoomSpace(id: 'sp-fl1-rm2', name: 'Classroom: Room 2', areaSqm: 46.0, ceilingHeight: 2.8),
        RoomSpace(id: 'sp-fl1-cr', name: 'Ground Comfort Rooms', areaSqm: 14.0, ceilingHeight: 2.7),
        RoomSpace(id: 'sp-fl1-hall', name: 'Hallways & Stair Landing (L1)', areaSqm: 32.0, ceilingHeight: 3.0),
      ],
      secondFloorSpaces: [
        RoomSpace(id: 'sp-fl2-faculty', name: 'Faculty & Admin Office', areaSqm: 70.0, ceilingHeight: 2.8),
        RoomSpace(id: 'sp-fl2-rm3', name: 'Classroom: Room 3', areaSqm: 46.0, ceilingHeight: 2.8),
        RoomSpace(id: 'sp-fl2-rm4', name: 'Classroom: Room 4', areaSqm: 46.0, ceilingHeight: 2.8),
        RoomSpace(id: 'sp-fl2-cr', name: 'Second Floor Comfort Rooms', areaSqm: 14.0, ceilingHeight: 2.7),
        RoomSpace(id: 'sp-fl2-hall', name: 'Corridor & Stair Landing (L2)', areaSqm: 30.0, ceilingHeight: 2.8),
      ],
      firstFloorAppliances: [
        // Demonstration Room
        ApplianceItem(id: 'fl1-a1', name: '6x 2x4 Low-Glare LED Troffers (Demo Room)', roomCategory: 'Demonstration Room', ratingVA: 240.0, quantity: 1, isLighting: true, circuitNumber: 1),
        ApplianceItem(id: 'fl1-a2', name: 'Teacher Podium & Media Convenience Outlets', roomCategory: 'Demonstration Room', ratingVA: 720.0, quantity: 1, isDedicatedCircuit: false, circuitNumber: 2),
        ApplianceItem(id: 'fl1-a3', name: 'Dedicated 2.5HP Inverter Split ACU (Demo)', roomCategory: 'Demonstration Room', ratingVA: 2600.0, quantity: 1, isDedicatedCircuit: true, circuitNumber: 3),

        // Welding & Fabrication Area (Tech-Voc heavy load)
        ApplianceItem(id: 'fl1-a4', name: 'IP65 High-Bay LED Luminaires (Welding Area)', roomCategory: 'Welding & Fab Shop Area', ratingVA: 300.0, quantity: 1, isLighting: true, circuitNumber: 1),
        ApplianceItem(id: 'fl1-a5', name: 'Dedicated AC Arc / Inverter Welder Outlet #1', roomCategory: 'Welding & Fab Shop Area', ratingVA: 5000.0, quantity: 1, isDedicatedCircuit: true, circuitNumber: 4),
        ApplianceItem(id: 'fl1-a6', name: 'Dedicated AC Arc / Inverter Welder Outlet #2', roomCategory: 'Welding & Fab Shop Area', ratingVA: 5000.0, quantity: 1, isDedicatedCircuit: true, circuitNumber: 5),
        ApplianceItem(id: 'fl1-a7', name: 'Heavy Duty Fume Exhaust & Ventilation Blower', roomCategory: 'Welding & Fab Shop Area', ratingVA: 750.0, quantity: 1, isDedicatedCircuit: true, circuitNumber: 6),

        // Room 1 (Classroom)
        ApplianceItem(id: 'fl1-a8', name: '8x 2x4 Low-Glare Classroom LED Panels (Room 1)', roomCategory: 'Classroom: Room 1', ratingVA: 320.0, quantity: 1, isLighting: true, circuitNumber: 7),
        ApplianceItem(id: 'fl1-a9', name: '4x Duplex Student & Teaching Convenience Outlets', roomCategory: 'Classroom: Room 1', ratingVA: 720.0, quantity: 1, isDedicatedCircuit: false, circuitNumber: 8),
        ApplianceItem(id: 'fl1-a10', name: '4x Heavy Orbit / Ceiling Circulation Fans', roomCategory: 'Classroom: Room 1', ratingVA: 320.0, quantity: 1, isDedicatedCircuit: false, circuitNumber: 8),

        // Room 2 (Classroom)
        ApplianceItem(id: 'fl1-a11', name: '8x 2x4 Low-Glare Classroom LED Panels (Room 2)', roomCategory: 'Classroom: Room 2', ratingVA: 320.0, quantity: 1, isLighting: true, circuitNumber: 7),
        ApplianceItem(id: 'fl1-a12', name: '4x Duplex Student & Teaching Convenience Outlets', roomCategory: 'Classroom: Room 2', ratingVA: 720.0, quantity: 1, isDedicatedCircuit: false, circuitNumber: 9),
        ApplianceItem(id: 'fl1-a13', name: '4x Heavy Orbit / Ceiling Circulation Fans', roomCategory: 'Classroom: Room 2', ratingVA: 320.0, quantity: 1, isDedicatedCircuit: false, circuitNumber: 9),

        // Ground CR & Corridors
        ApplianceItem(id: 'fl1-a14', name: 'Corridor, Landing & CR Moisture-Proof LED Fixtures', roomCategory: 'Hallways & Stair Landing (L1)', ratingVA: 220.0, quantity: 1, isLighting: true, circuitNumber: 1),
      ],
      secondFloorAppliances: [
        // Faculty & Admin Office
        ApplianceItem(id: 'fl2-a1', name: '12x 2x4 Anti-Glare Daylight LED Panels (Faculty)', roomCategory: 'Faculty & Admin Office', ratingVA: 480.0, quantity: 1, isLighting: true, circuitNumber: 1),
        ApplianceItem(id: 'fl2-a2', name: 'Faculty Workstation PC Outlets (12 Duplex Receptacles)', roomCategory: 'Faculty & Admin Office', ratingVA: 2160.0, quantity: 1, isDedicatedCircuit: false, circuitNumber: 2),
        ApplianceItem(id: 'fl2-a3', name: 'Dedicated Network Server / Telecom Rack', roomCategory: 'Faculty & Admin Office', ratingVA: 1200.0, quantity: 1, isDedicatedCircuit: true, circuitNumber: 3),
        ApplianceItem(id: 'fl2-a4', name: 'Dedicated 3.0HP Inverter Floor-Mounted ACU (Faculty)', roomCategory: 'Faculty & Admin Office', ratingVA: 3200.0, quantity: 1, isDedicatedCircuit: true, circuitNumber: 4),

        // Room 3 (Classroom)
        ApplianceItem(id: 'fl2-a5', name: '8x 2x4 Low-Glare Classroom LED Panels (Room 3)', roomCategory: 'Classroom: Room 3', ratingVA: 320.0, quantity: 1, isLighting: true, circuitNumber: 5),
        ApplianceItem(id: 'fl2-a6', name: '4x Duplex Student & Teaching Convenience Outlets', roomCategory: 'Classroom: Room 3', ratingVA: 720.0, quantity: 1, isDedicatedCircuit: false, circuitNumber: 6),
        ApplianceItem(id: 'fl2-a7', name: '4x Heavy Orbit / Ceiling Circulation Fans', roomCategory: 'Classroom: Room 3', ratingVA: 320.0, quantity: 1, isDedicatedCircuit: false, circuitNumber: 6),

        // Room 4 (Classroom)
        ApplianceItem(id: 'fl2-a8', name: '8x 2x4 Low-Glare Classroom LED Panels (Room 4)', roomCategory: 'Classroom: Room 4', ratingVA: 320.0, quantity: 1, isLighting: true, circuitNumber: 5),
        ApplianceItem(id: 'fl2-a9', name: '4x Duplex Student & Teaching Convenience Outlets', roomCategory: 'Classroom: Room 4', ratingVA: 720.0, quantity: 1, isDedicatedCircuit: false, circuitNumber: 7),
        ApplianceItem(id: 'fl2-a10', name: '4x Heavy Orbit / Ceiling Circulation Fans', roomCategory: 'Classroom: Room 4', ratingVA: 320.0, quantity: 1, isDedicatedCircuit: false, circuitNumber: 7),

        // Second Floor CR & Corridors
        ApplianceItem(id: 'fl2-a11', name: 'Corridor & Stair Landing LED Bulkheads', roomCategory: 'Corridor & Stair Landing (L2)', ratingVA: 180.0, quantity: 1, isLighting: true, circuitNumber: 1),
      ],
    );
  }
}

class MultiPanelInstitutionalRiser {
  final SingleLineDiagramData mdp; // Main Distribution Panel
  final SingleLineDiagramData lp1; // First Floor Lighting & Power
  final SingleLineDiagramData lp2; // Second Floor Lighting & Power

  const MultiPanelInstitutionalRiser({
    required this.mdp,
    required this.lp1,
    required this.lp2,
  });

  /// Computes the complete Two-Storey Institutional Riser & Panels
  static MultiPanelInstitutionalRiser compute(InstitutionalBuildingPreset preset, {String utility = 'CANORECO'}) {
    // 1. Generate LP-1 (First Floor)
    final lp1Project = Project(
      id: 'proj-lp1',
      title: '${preset.institutionName} - Floor 1',
      clientName: 'San Lorenzo Ruiz College',
      clientContact: 'N/A',
      siteAddress: preset.location,
      contractAmount: 0.0,
      createdAt: DateTime.now(),
      utilityProvider: utility,
      spaces: preset.firstFloorSpaces,
      applianceLoads: preset.firstFloorAppliances,
      phases: [],
    );
    final rawLp1 = SldEngine.generateFromProject(lp1Project);
    final sldLp1 = SingleLineDiagramData(
      feeder: rawLp1.feeder,
      branchCircuits: rawLp1.branchCircuits,
      panelName: 'LP-1 (First Floor Lighting & Power Panel)',
      utilityProvider: utility,
    );

    // 2. Generate LP-2 (Second Floor)
    final lp2Project = Project(
      id: 'proj-lp2',
      title: '${preset.institutionName} - Floor 2',
      clientName: 'San Lorenzo Ruiz College',
      clientContact: 'N/A',
      siteAddress: preset.location,
      contractAmount: 0.0,
      createdAt: DateTime.now(),
      utilityProvider: utility,
      spaces: preset.secondFloorSpaces,
      applianceLoads: preset.secondFloorAppliances,
      phases: [],
    );
    final rawLp2 = SldEngine.generateFromProject(lp2Project);
    final sldLp2 = SingleLineDiagramData(
      feeder: rawLp2.feeder,
      branchCircuits: rawLp2.branchCircuits,
      panelName: 'LP-2 (Second Floor Lighting & Power Panel)',
      utilityProvider: utility,
    );

    // 3. Compute Main Distribution Panel (MDP)
    final double totalConnectedVA = sldLp1.feeder.totalConnectedVA + sldLp2.feeder.totalConnectedVA;
    // Institutional Diversity Factor between floors: 85%
    final double netDemandVA = (sldLp1.feeder.netDemandVA + sldLp2.feeder.netDemandVA) * 0.90;
    final double netCurrentAmps = netDemandVA / 230.0;
    final double designMainAmps = netCurrentAmps * 1.25;

    int mdpMainBreaker = 125;
    for (final rating in [125, 150, 175, 200, 225, 250, 300, 400]) {
      if (rating >= designMainAmps) {
        mdpMainBreaker = rating;
        break;
      }
    }

    String mdpWire = '2 - 50 mm² THHN';
    String mdpConduit = '50 mm Ø RSC';
    String mdpGround = '1 - 14.0 mm² Bare Cu';
    if (mdpMainBreaker > 200) {
      mdpWire = '2 - 80 mm² THHN';
      mdpConduit = '65 mm Ø RSC';
      mdpGround = '1 - 22.0 mm² Bare Cu';
    }

    final mdpFeeder = SldFeederSpec(
      totalConnectedVA: totalConnectedVA,
      netDemandVA: netDemandVA,
      netCurrentAmps: netCurrentAmps,
      mainBreakerAmps: mdpMainBreaker,
      mainBreakerDescription: '$mdpMainBreaker AT / 250 AF, 2-Pole, 230V, 60Hz, 25kAIC Industrial MCB',
      feederWireDescription: mdpWire,
      groundingDescription: '$mdpGround to Grounding Mesh Grid (4 Rods)',
      conduitDescription: mdpConduit,
      serviceDropDescription: '230V, 1-Phase, 2-Wire, 60Hz Overhead Institutional Drop ($utility)',
    );

    final mdpBranchFeeders = [
      SldBranchCircuit(
        circuitNumber: 1,
        description: 'Sub-feeder to Panel LP-1 (First Floor Distribution)',
        loadVA: sldLp1.feeder.netDemandVA,
        loadCurrentAmps: sldLp1.feeder.netCurrentAmps,
        breakerRatingAmps: sldLp1.feeder.mainBreakerAmps,
        poles: 2,
        wireSizeDescription: sldLp1.feeder.feederWireDescription,
        conduitDescription: sldLp1.feeder.conduitDescription,
      ),
      SldBranchCircuit(
        circuitNumber: 2,
        description: 'Sub-feeder to Panel LP-2 (Second Floor Distribution)',
        loadVA: sldLp2.feeder.netDemandVA,
        loadCurrentAmps: sldLp2.feeder.netCurrentAmps,
        breakerRatingAmps: sldLp2.feeder.mainBreakerAmps,
        poles: 2,
        wireSizeDescription: sldLp2.feeder.feederWireDescription,
        conduitDescription: sldLp2.feeder.conduitDescription,
      ),
      SldBranchCircuit(
        circuitNumber: 3,
        description: 'SPARE Sub-feeder (Future 3rd Floor / Expansion)',
        loadVA: 0.0,
        loadCurrentAmps: 0.0,
        breakerRatingAmps: 60,
        poles: 2,
        wireSizeDescription: '2 - 22 mm² THHN',
        conduitDescription: '25 mm Ø PVC',
        isSpare: true,
      ),
    ];

    final sldMdp = SingleLineDiagramData(
      feeder: mdpFeeder,
      branchCircuits: mdpBranchFeeders,
      panelName: 'MDP (Main Distribution Panelboard)',
      utilityProvider: utility,
    );

    return MultiPanelInstitutionalRiser(
      mdp: sldMdp,
      lp1: sldLp1,
      lp2: sldLp2,
    );
  }
}
