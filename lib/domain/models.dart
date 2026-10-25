// BANAAG Core Domain Models with Full JSON Serialization for Permanent Persistence

enum ProjectPhaseType {
  consultation(1, 'Consultation & Site Assessment', 'Needs analysis, service drop coordinates (Meralco/Coop)'),
  permitting(2, 'Design & OBO Permitting', 'Load computation, PEE sealed plans, Electrical Permit'),
  procurement(3, 'Procurement & Mobilization', 'BOM purchasing, PS/ICC marks quality verification'),
  roughIn(4, 'Rough-in Phase (Pre-Cover Gate)', 'Piping, chipping, wire pull allowance, mandatory photo QA'),
  trimOut(5, 'Trim-Out Phase (Devices & Panel)', 'Receptacles, switches, lighting fixtures, panel termination'),
  testing(6, 'Testing & Commissioning', 'Megger insulation test (>=1MΩ), continuity, live load testing'),
  turnover(7, 'CEI & Utility Energization', 'LGU CEI release, meter installation, As-Built handover');

  final int phaseNumber;
  final String title;
  final String description;
  const ProjectPhaseType(this.phaseNumber, this.title, this.description);
}

class PhaseCheckItem {
  final String id;
  final String title;
  final bool isMandatory;
  bool isCompleted;
  String? photoProofUri;
  String? notes;

  PhaseCheckItem({
    required this.id,
    required this.title,
    this.isMandatory = true,
    this.isCompleted = false,
    this.photoProofUri,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'isMandatory': isMandatory,
    'isCompleted': isCompleted,
    'photoProofUri': photoProofUri,
    'notes': notes,
  };

  factory PhaseCheckItem.fromJson(Map<String, dynamic> json) => PhaseCheckItem(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    isMandatory: json['isMandatory'] ?? true,
    isCompleted: json['isCompleted'] ?? false,
    photoProofUri: json['photoProofUri'],
    notes: json['notes'],
  );
}

class ProjectPhase {
  final ProjectPhaseType type;
  bool isCompleted;
  DateTime? completedAt;
  final List<PhaseCheckItem> checklist;

  ProjectPhase({
    required this.type,
    this.isCompleted = false,
    this.completedAt,
    required this.checklist,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'isCompleted': isCompleted,
    'completedAt': completedAt?.toIso8601String(),
    'checklist': checklist.map((c) => c.toJson()).toList(),
  };

  factory ProjectPhase.fromJson(Map<String, dynamic> json) => ProjectPhase(
    type: ProjectPhaseType.values.firstWhere(
      (t) => t.name == json['type'],
      orElse: () => ProjectPhaseType.consultation,
    ),
    isCompleted: json['isCompleted'] ?? false,
    completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
    checklist: (json['checklist'] as List<dynamic>?)
            ?.map((c) => PhaseCheckItem.fromJson(c as Map<String, dynamic>))
            .toList() ??
        [],
  );
}

class ApplianceItem {
  final String id;
  final String name;
  final String roomCategory; // 'Living & Dining', 'Kitchen', 'Bedrooms', 'Bathrooms & Laundry', 'Outdoor'
  final double ratingVA; // Standard connected volt-amperes
  int quantity;
  final bool isDedicatedCircuit; // e.g. Aircon, Water Heater, Range
  final bool isLighting; // true = Lighting, false = Power/Outlet
  int circuitNumber; // PEC Circuit number assignment (e.g. 1, 2, 3...)

  ApplianceItem({
    required this.id,
    required this.name,
    required this.roomCategory,
    required this.ratingVA,
    this.quantity = 1,
    this.isDedicatedCircuit = false,
    this.isLighting = false,
    this.circuitNumber = 1,
  });

  double get totalVA => ratingVA * quantity;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'roomCategory': roomCategory,
    'ratingVA': ratingVA,
    'quantity': quantity,
    'isDedicatedCircuit': isDedicatedCircuit,
    'isLighting': isLighting,
    'circuitNumber': circuitNumber,
  };

  factory ApplianceItem.fromJson(Map<String, dynamic> json) => ApplianceItem(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    roomCategory: json['roomCategory'] ?? 'General',
    ratingVA: (json['ratingVA'] as num?)?.toDouble() ?? 100.0,
    quantity: json['quantity'] ?? 1,
    isDedicatedCircuit: json['isDedicatedCircuit'] ?? false,
    isLighting: json['isLighting'] ?? false,
    circuitNumber: json['circuitNumber'] ?? (json['isLighting'] == true ? 1 : (json['isDedicatedCircuit'] == true ? 3 : 2)),
  );
}

class RoomSpace {
  final String id;
  final String name; // e.g. 'Living & Dining', 'Master Bedroom', 'Dirty Kitchen'
  final double areaSqm;
  final double ceilingHeight;
  final String shapeType; // 'RECTANGULAR', 'L_SHAPE', 'T_SHAPE', 'CUSTOM'
  final double cutoutDepth;
  final double cutoutWidth;
  final double? canvasX;
  final double? canvasY;
  final double? canvasWidth;
  final double? canvasHeight;
  final double? perimeterMeters;
  final double? rcrValue;
  final List<Map<String, double>>? polygonVertices;

  RoomSpace({
    required this.id,
    required this.name,
    this.areaSqm = 16.0,
    this.ceilingHeight = 2.7,
    this.shapeType = 'RECTANGULAR',
    this.cutoutDepth = 0.0,
    this.cutoutWidth = 0.0,
    this.canvasX,
    this.canvasY,
    this.canvasWidth,
    this.canvasHeight,
    this.perimeterMeters,
    this.rcrValue,
    this.polygonVertices,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'areaSqm': areaSqm,
    'ceilingHeight': ceilingHeight,
    'shapeType': shapeType,
    'cutoutDepth': cutoutDepth,
    'cutoutWidth': cutoutWidth,
    'canvasX': canvasX,
    'canvasY': canvasY,
    'canvasWidth': canvasWidth,
    'canvasHeight': canvasHeight,
    'perimeterMeters': perimeterMeters,
    'rcrValue': rcrValue,
    'polygonVertices': polygonVertices,
  };

  factory RoomSpace.fromJson(Map<String, dynamic> json) => RoomSpace(
    id: json['id'] ?? '',
    name: json['name'] ?? 'Custom Space',
    areaSqm: (json['areaSqm'] as num?)?.toDouble() ?? 16.0,
    ceilingHeight: (json['ceilingHeight'] as num?)?.toDouble() ?? 2.7,
    shapeType: json['shapeType'] ?? 'RECTANGULAR',
    cutoutDepth: (json['cutoutDepth'] as num?)?.toDouble() ?? 0.0,
    cutoutWidth: (json['cutoutWidth'] as num?)?.toDouble() ?? 0.0,
    canvasX: (json['canvasX'] as num?)?.toDouble(),
    canvasY: (json['canvasY'] as num?)?.toDouble(),
    canvasWidth: (json['canvasWidth'] as num?)?.toDouble(),
    canvasHeight: (json['canvasHeight'] as num?)?.toDouble(),
    perimeterMeters: (json['perimeterMeters'] as num?)?.toDouble(),
    rcrValue: (json['rcrValue'] as num?)?.toDouble(),
    polygonVertices: (json['polygonVertices'] as List<dynamic>?)
        ?.map((e) => {
              'x': ((e as Map)['x'] as num).toDouble(),
              'y': (e['y'] as num).toDouble(),
            })
        .toList(),
  );
}

class PanelboardSpec {
  final String id;
  String tag; // e.g. 'MDP', 'LP-1', 'LP-2', 'PP-ACU'
  String name; // e.g. 'Main Distribution Panel', 'First Floor Lighting & Power', etc.
  bool isMain; // true if this is the Main Distribution Panelboard
  String? fedFromPanelId; // null if fed directly from Utility Service Entrance / Meter
  int enclosureBranches; // 6, 8, 12, 16, 20 branches

  PanelboardSpec({
    required this.id,
    required this.tag,
    required this.name,
    this.isMain = false,
    this.fedFromPanelId,
    this.enclosureBranches = 12,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'tag': tag,
    'name': name,
    'isMain': isMain,
    'fedFromPanelId': fedFromPanelId,
    'enclosureBranches': enclosureBranches,
  };

  factory PanelboardSpec.fromJson(Map<String, dynamic> json) => PanelboardSpec(
    id: json['id'] ?? '',
    tag: json['tag'] ?? 'LP-1',
    name: json['name'] ?? 'Distribution Panelboard',
    isMain: json['isMain'] ?? false,
    fedFromPanelId: json['fedFromPanelId'],
    enclosureBranches: json['enclosureBranches'] ?? 12,
  );
}

class CanvasPoint {
  final String id;
  final String type; // 'PANEL', 'LIGHT', 'SWITCH_1G', 'OUTLET_DUPLEX', 'ACU'
  final String label;
  double x;
  double y;
  final int circuitNumber;

  CanvasPoint({
    required this.id,
    required this.type,
    required this.label,
    required this.x,
    required this.y,
    this.circuitNumber = 1,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'label': label,
    'x': x,
    'y': y,
    'circuitNumber': circuitNumber,
  };

  factory CanvasPoint.fromJson(Map<String, dynamic> json) => CanvasPoint(
    id: json['id'] ?? '',
    type: json['type'] ?? 'OUTLET_DUPLEX',
    label: json['label'] ?? '',
    x: (json['x'] as num?)?.toDouble() ?? 0.0,
    y: (json['y'] as num?)?.toDouble() ?? 0.0,
    circuitNumber: json['circuitNumber'] ?? 1,
  );
}

class ConduitRoute {
  final String id;
  final String fromPointId;
  final String toPointId;
  final double measuredLengthMeters;
  final int conductorCount; // usually 2 or 3 (Phase + Neutral + Ground)

  ConduitRoute({
    required this.id,
    required this.fromPointId,
    required this.toPointId,
    required this.measuredLengthMeters,
    this.conductorCount = 3,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'fromPointId': fromPointId,
    'toPointId': toPointId,
    'measuredLengthMeters': measuredLengthMeters,
    'conductorCount': conductorCount,
  };

  factory ConduitRoute.fromJson(Map<String, dynamic> json) => ConduitRoute(
    id: json['id'] ?? '',
    fromPointId: json['fromPointId'] ?? '',
    toPointId: json['toPointId'] ?? '',
    measuredLengthMeters: (json['measuredLengthMeters'] as num?)?.toDouble() ?? 3.5,
    conductorCount: json['conductorCount'] ?? 3,
  );
}

class SiteStructureAssessment {
  final List<String> structureTypes; // e.g., 'Concrete / CHB', 'Timber / Wood Frame', etc.
  final String racewayRecommendation; // e.g., 'Schedule 40 uPVC Pipe (Thick Wall Embedment)'
  final String boxRecommendation; // e.g., 'Deep PVC Utility Box with mounting tabs'
  final String fastenerRecommendation; // e.g., 'Masonry Tox #6 with Stainless Screws'
  final String notes;

  const SiteStructureAssessment({
    required this.structureTypes,
    required this.racewayRecommendation,
    required this.boxRecommendation,
    required this.fastenerRecommendation,
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
    'structureTypes': structureTypes,
    'racewayRecommendation': racewayRecommendation,
    'boxRecommendation': boxRecommendation,
    'fastenerRecommendation': fastenerRecommendation,
    'notes': notes,
  };

  factory SiteStructureAssessment.fromJson(Map<String, dynamic> json) => SiteStructureAssessment(
    structureTypes: (json['structureTypes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? ['Concrete / CHB'],
    racewayRecommendation: json['racewayRecommendation'] ?? 'Schedule 40 Thick Wall uPVC',
    boxRecommendation: json['boxRecommendation'] ?? 'Deep PVC Utility Box',
    fastenerRecommendation: json['fastenerRecommendation'] ?? 'Masonry Tox & Screws',
    notes: json['notes'] ?? '',
  );
}

class UtilityServiceDropAssessment {
  final String poleNumberTag; // SIN / Pole tag, e.g. "SIN-10492" or "M-4821"
  final double distanceToPoleMeters; // Estimated service drop span
  final bool crossesRoadway; // If crossing street/highway, PEC Sec. 2.30.2.3(B)(4) requires 5,500 mm (5.5m) clearance
  final String serviceEntranceType; // 'Overhead Masthead / Weatherhead' vs 'Underground Service Lateral'
  final String utilityProvider; // Meralco, CANORECO, CASURECO, etc.
  final String notes;

  const UtilityServiceDropAssessment({
    required this.poleNumberTag,
    required this.distanceToPoleMeters,
    this.crossesRoadway = false,
    this.serviceEntranceType = 'Overhead Masthead / Weatherhead',
    this.utilityProvider = 'Meralco',
    this.notes = '',
  });

  // Business Logic & Verbatim PEC 2017 Sec. 2.30.2.3(B) (Pages 72-73) Checks:
  // - Sec. 2.30.2.3(B)(4): 5,500 mm (5.5m) over public streets, alleys, roads, and truck parking
  // - Sec. 2.30.2.3(B)(2)-(3): 3,700 mm (3.7m) PEC minimum over residential driveways <=300V to ground (4,500 mm / 4.5m DU standard / >300V)
  bool get requiresIntermediatePole => distanceToPoleMeters > 30.0;
  double get requiredVerticalClearanceMeters => crossesRoadway ? 5.5 : 4.5;
  double get pecMinimumResidentialClearanceMeters => crossesRoadway ? 5.5 : 3.7;
  double get estimatedDuplexWireMeters => distanceToPoleMeters + 3.0; // +3m drip loop & masthead allowance

  String get pecComplianceNote {
    if (requiresIntermediatePole) {
      return '⚠️ BABALA (PEC Sec. 2.30.2.3 & DU Standards): Ang ${distanceToPoleMeters.toStringAsFixed(1)}m ay lagpas sa 30m maximum service span. Kinakailangan magtayo ng secondary intermediate pole (inter-pole) para hindi sumayad ang wire.';
    }
    return '✅ PEC 2017 Sec. 2.30.2.3(B) Compliant (Page 73): Pasok sa 30m span limit (Clearance: ${requiredVerticalClearanceMeters.toStringAsFixed(1)}m DU / ${pecMinimumResidentialClearanceMeters.toStringAsFixed(1)}m PEC min ${crossesRoadway ? 'Tawid-Kalsada' : 'Residential Driveway'}).';
  }

  Map<String, dynamic> toJson() => {
    'poleNumberTag': poleNumberTag,
    'distanceToPoleMeters': distanceToPoleMeters,
    'crossesRoadway': crossesRoadway,
    'serviceEntranceType': serviceEntranceType,
    'utilityProvider': utilityProvider,
    'notes': notes,
  };

  factory UtilityServiceDropAssessment.fromJson(Map<String, dynamic> json) => UtilityServiceDropAssessment(
    poleNumberTag: json['poleNumberTag'] ?? '',
    distanceToPoleMeters: (json['distanceToPoleMeters'] as num?)?.toDouble() ?? 15.0,
    crossesRoadway: json['crossesRoadway'] ?? false,
    serviceEntranceType: json['serviceEntranceType'] ?? 'Overhead Masthead / Weatherhead',
    utilityProvider: json['utilityProvider'] ?? 'Meralco',
    notes: json['notes'] ?? '',
  );
}

class RoomGeometry {
  final String roomType; // 'RECTANGULAR', 'L_SHAPE'
  final double leftWallMeters; // e.g. 4.5
  final double totalWidthMeters; // e.g. 4.0 (2m + 2m)
  final double cutoutWidthMeters; // e.g. 1.0 (hallway/cutout)
  final double cutoutDepthMeters; // e.g. 2.5
  final double rightWallMeters; // e.g. 4.5

  const RoomGeometry({
    this.roomType = 'L_SHAPE',
    this.leftWallMeters = 4.5,
    this.totalWidthMeters = 4.0,
    this.cutoutWidthMeters = 1.0,
    this.cutoutDepthMeters = 2.5,
    this.rightWallMeters = 4.5,
  });

  double get computedAreaSqm {
    if (roomType == 'RECTANGULAR') {
      return leftWallMeters * totalWidthMeters;
    }
    // L-Shape calculation: (Total Width * Left Wall) - (Cutout Width * Cutout Depth)
    final baseArea = totalWidthMeters * leftWallMeters;
    final cutoutArea = cutoutWidthMeters * cutoutDepthMeters;
    return (baseArea - cutoutArea).clamp(1.0, 999.0);
  }

  Map<String, dynamic> toJson() => {
    'roomType': roomType,
    'leftWallMeters': leftWallMeters,
    'totalWidthMeters': totalWidthMeters,
    'cutoutWidthMeters': cutoutWidthMeters,
    'cutoutDepthMeters': cutoutDepthMeters,
    'rightWallMeters': rightWallMeters,
  };

  factory RoomGeometry.fromJson(Map<String, dynamic> json) => RoomGeometry(
    roomType: json['roomType'] ?? 'L_SHAPE',
    leftWallMeters: (json['leftWallMeters'] as num?)?.toDouble() ?? 4.5,
    totalWidthMeters: (json['totalWidthMeters'] as num?)?.toDouble() ?? 4.0,
    cutoutWidthMeters: (json['cutoutWidthMeters'] as num?)?.toDouble() ?? 1.0,
    cutoutDepthMeters: (json['cutoutDepthMeters'] as num?)?.toDouble() ?? 2.5,
    rightWallMeters: (json['rightWallMeters'] as num?)?.toDouble() ?? 4.5,
  );
}

class Project {
  final String id;
  final String title;
  final String clientName;
  final String clientContact;
  final String siteAddress;
  final String utilityProvider; // e.g. Meralco, CANORECO
  double contractAmount;
  final double retentionPercent; // default 10%
  int currentPhaseNumber;
  final String intakeMode; // 'SITE_INTERVIEW', 'BLUEPRINT_PHOTO', 'AUTOCAD_DXF'
  bool isArchived;
  SiteStructureAssessment? siteStructure;
  UtilityServiceDropAssessment? utilityServiceDrop;
  RoomGeometry? roomGeometry;
  String? blueprintImagePath;
  List<RoomSpace> spaces;
  List<ApplianceItem> applianceLoads;
  List<CanvasPoint> canvasPoints;
  List<ConduitRoute> conduitRoutes;
  List<PanelboardSpec> panelboards;
  final List<ProjectPhase> phases;
  final DateTime createdAt;
  double? calibrationPixelsPerMeter;
  bool invertBlueprint;
  bool isCommitted;

  Project({
    required this.id,
    required this.title,
    required this.clientName,
    required this.clientContact,
    required this.siteAddress,
    this.utilityProvider = 'Meralco',
    required this.contractAmount,
    this.retentionPercent = 10.0,
    this.currentPhaseNumber = 1,
    this.intakeMode = 'SITE_INTERVIEW',
    this.isArchived = false,
    this.siteStructure,
    this.utilityServiceDrop,
    this.roomGeometry,
    this.blueprintImagePath,
    this.calibrationPixelsPerMeter,
    this.invertBlueprint = false,
    this.isCommitted = false,
    List<RoomSpace>? spaces,
    List<ApplianceItem>? applianceLoads,
    List<CanvasPoint>? canvasPoints,
    List<ConduitRoute>? conduitRoutes,
    List<PanelboardSpec>? panelboards,
    required this.phases,
    required this.createdAt,
  })  : spaces = spaces ?? [
          RoomSpace(id: 'sp-1', name: 'Living & Dining', areaSqm: 24.0, ceilingHeight: 2.7),
          RoomSpace(id: 'sp-2', name: 'Kitchen', areaSqm: 14.0, ceilingHeight: 2.7),
          RoomSpace(id: 'sp-3', name: 'Master Bedroom', areaSqm: 18.0, ceilingHeight: 2.7),
          RoomSpace(id: 'sp-4', name: 'Bath & Laundry', areaSqm: 8.0, ceilingHeight: 2.6),
        ],
        applianceLoads = applianceLoads ?? [],
        canvasPoints = canvasPoints ?? [],
        conduitRoutes = conduitRoutes ?? [],
        panelboards = panelboards ?? [
          PanelboardSpec(id: 'panel-main', tag: 'LP-1', name: 'Main Lighting & Power Panel', isMain: true),
        ];

  double get retentionAmount => contractAmount * (retentionPercent / 100.0);
  double get billableAmount => contractAmount - retentionAmount;
  double get totalConnectedLoadVA => applianceLoads.fold(0.0, (sum, item) => sum + item.totalVA);

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'clientName': clientName,
    'clientContact': clientContact,
    'siteAddress': siteAddress,
    'utilityProvider': utilityProvider,
    'contractAmount': contractAmount,
    'retentionPercent': retentionPercent,
    'currentPhaseNumber': currentPhaseNumber,
    'intakeMode': intakeMode,
    'isArchived': isArchived,
    'siteStructure': siteStructure?.toJson(),
    'utilityServiceDrop': utilityServiceDrop?.toJson(),
    'roomGeometry': roomGeometry?.toJson(),
    'blueprintImagePath': blueprintImagePath,
    'calibrationPixelsPerMeter': calibrationPixelsPerMeter,
    'invertBlueprint': invertBlueprint,
    'isCommitted': isCommitted,
    'spaces': spaces.map((s) => s.toJson()).toList(),
    'applianceLoads': applianceLoads.map((a) => a.toJson()).toList(),
    'canvasPoints': canvasPoints.map((c) => c.toJson()).toList(),
    'conduitRoutes': conduitRoutes.map((r) => r.toJson()).toList(),
    'panelboards': panelboards.map((p) => p.toJson()).toList(),
    'phases': phases.map((p) => p.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory Project.fromJson(Map<String, dynamic> json) => Project(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    clientName: json['clientName'] ?? '',
    clientContact: json['clientContact'] ?? '',
    siteAddress: json['siteAddress'] ?? '',
    utilityProvider: json['utilityProvider'] ?? 'Meralco',
    contractAmount: (json['contractAmount'] as num?)?.toDouble() ?? 0.0,
    retentionPercent: (json['retentionPercent'] as num?)?.toDouble() ?? 10.0,
    currentPhaseNumber: json['currentPhaseNumber'] ?? 1,
    intakeMode: json['intakeMode'] ?? 'SITE_INTERVIEW',
    isArchived: json['isArchived'] ?? false,
    siteStructure: json['siteStructure'] != null
        ? SiteStructureAssessment.fromJson(json['siteStructure'] as Map<String, dynamic>)
        : null,
    utilityServiceDrop: json['utilityServiceDrop'] != null
        ? UtilityServiceDropAssessment.fromJson(json['utilityServiceDrop'] as Map<String, dynamic>)
        : null,
    roomGeometry: json['roomGeometry'] != null
        ? RoomGeometry.fromJson(json['roomGeometry'] as Map<String, dynamic>)
        : null,
    blueprintImagePath: json['blueprintImagePath'] as String?,
    calibrationPixelsPerMeter: (json['calibrationPixelsPerMeter'] as num?)?.toDouble(),
    invertBlueprint: json['invertBlueprint'] ?? false,
    isCommitted: json['isCommitted'] ?? false,
    spaces: (json['spaces'] as List<dynamic>?)
            ?.map((s) => RoomSpace.fromJson(s as Map<String, dynamic>))
            .toList() ??
        [
          RoomSpace(id: 'sp-1', name: 'Living & Dining', areaSqm: 24.0, ceilingHeight: 2.7),
          RoomSpace(id: 'sp-2', name: 'Kitchen', areaSqm: 14.0, ceilingHeight: 2.7),
          RoomSpace(id: 'sp-3', name: 'Master Bedroom', areaSqm: 18.0, ceilingHeight: 2.7),
          RoomSpace(id: 'sp-4', name: 'Bath & Laundry', areaSqm: 8.0, ceilingHeight: 2.6),
        ],
    applianceLoads: (json['applianceLoads'] as List<dynamic>?)
            ?.map((a) => ApplianceItem.fromJson(a as Map<String, dynamic>))
            .toList() ??
        [],
    canvasPoints: (json['canvasPoints'] as List<dynamic>?)
            ?.map((c) => CanvasPoint.fromJson(c as Map<String, dynamic>))
            .toList() ??
        [],
    conduitRoutes: (json['conduitRoutes'] as List<dynamic>?)
            ?.map((r) => ConduitRoute.fromJson(r as Map<String, dynamic>))
            .toList() ??
        [],
    panelboards: (json['panelboards'] as List<dynamic>?)
            ?.map((p) => PanelboardSpec.fromJson(p as Map<String, dynamic>))
            .toList() ??
        [
          PanelboardSpec(id: 'panel-main', tag: 'LP-1', name: 'Main Lighting & Power Panel', isMain: true),
        ],
    phases: (json['phases'] as List<dynamic>?)
            ?.map((p) => ProjectPhase.fromJson(p as Map<String, dynamic>))
            .toList() ??
        [],
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
  );
}

class VariationOrder {
  final String id;
  final String projectId;
  final String description;
  final double additionalAmount;
  final DateTime requestDate;
  bool isSignedByClient;
  String? signatureToken;

  VariationOrder({
    required this.id,
    required this.projectId,
    required this.description,
    required this.additionalAmount,
    required this.requestDate,
    this.isSignedByClient = false,
    this.signatureToken,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'projectId': projectId,
    'description': description,
    'additionalAmount': additionalAmount,
    'requestDate': requestDate.toIso8601String(),
    'isSignedByClient': isSignedByClient,
    'signatureToken': signatureToken,
  };

  factory VariationOrder.fromJson(Map<String, dynamic> json) => VariationOrder(
    id: json['id'] ?? '',
    projectId: json['projectId'] ?? '',
    description: json['description'] ?? '',
    additionalAmount: (json['additionalAmount'] as num?)?.toDouble() ?? 0.0,
    requestDate: json['requestDate'] != null ? DateTime.parse(json['requestDate']) : DateTime.now(),
    isSignedByClient: json['isSignedByClient'] ?? false,
    signatureToken: json['signatureToken'],
  );
}

class ManpowerLog {
  final String id;
  final String workerName;
  final String role; // 'RME', 'Journeyman Electrician', 'Helper'
  final double dailyRate;
  final DateTime date;
  final bool isPresent;
  final double overtimeHours;

  ManpowerLog({
    required this.id,
    required this.workerName,
    required this.role,
    required this.dailyRate,
    required this.date,
    this.isPresent = true,
    this.overtimeHours = 0.0,
  });

  double get computedPay {
    if (!isPresent) return 0.0;
    final double hourly = dailyRate / 8.0;
    return dailyRate + (overtimeHours * hourly * 1.25);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'workerName': workerName,
    'role': role,
    'dailyRate': dailyRate,
    'date': date.toIso8601String(),
    'isPresent': isPresent,
    'overtimeHours': overtimeHours,
  };

  factory ManpowerLog.fromJson(Map<String, dynamic> json) => ManpowerLog(
    id: json['id'] ?? '',
    workerName: json['workerName'] ?? '',
    role: json['role'] ?? 'Helper',
    dailyRate: (json['dailyRate'] as num?)?.toDouble() ?? 610.0,
    date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
    isPresent: json['isPresent'] ?? true,
    overtimeHours: (json['overtimeHours'] as num?)?.toDouble() ?? 0.0,
  );
}
