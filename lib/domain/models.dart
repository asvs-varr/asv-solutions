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

  ApplianceItem({
    required this.id,
    required this.name,
    required this.roomCategory,
    required this.ratingVA,
    this.quantity = 1,
    this.isDedicatedCircuit = false,
  });

  double get totalVA => ratingVA * quantity;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'roomCategory': roomCategory,
    'ratingVA': ratingVA,
    'quantity': quantity,
    'isDedicatedCircuit': isDedicatedCircuit,
  };

  factory ApplianceItem.fromJson(Map<String, dynamic> json) => ApplianceItem(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    roomCategory: json['roomCategory'] ?? 'General',
    ratingVA: (json['ratingVA'] as num?)?.toDouble() ?? 100.0,
    quantity: json['quantity'] ?? 1,
    isDedicatedCircuit: json['isDedicatedCircuit'] ?? false,
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
  List<ApplianceItem> applianceLoads;
  List<CanvasPoint> canvasPoints;
  List<ConduitRoute> conduitRoutes;
  final List<ProjectPhase> phases;
  final DateTime createdAt;

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
    List<ApplianceItem>? applianceLoads,
    List<CanvasPoint>? canvasPoints,
    List<ConduitRoute>? conduitRoutes,
    required this.phases,
    required this.createdAt,
  })  : applianceLoads = applianceLoads ?? [],
        canvasPoints = canvasPoints ?? [],
        conduitRoutes = conduitRoutes ?? [];

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
    'applianceLoads': applianceLoads.map((a) => a.toJson()).toList(),
    'canvasPoints': canvasPoints.map((c) => c.toJson()).toList(),
    'conduitRoutes': conduitRoutes.map((r) => r.toJson()).toList(),
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
