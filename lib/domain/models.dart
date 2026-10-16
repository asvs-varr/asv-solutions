// BANAAG Core Domain Models

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
}

class Project {
  final String id;
  final String title;
  final String clientName;
  final String clientContact;
  final String siteAddress;
  final String utilityProvider; // e.g. Meralco, CANORECO
  final double contractAmount;
  final double retentionPercent; // default 10%
  int currentPhaseNumber;
  List<ApplianceItem> applianceLoads;
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
    required this.phases,
    required this.createdAt,
  }) : applianceLoads = applianceLoads ?? [];

  double get retentionAmount => contractAmount * (retentionPercent / 100.0);
  double get billableAmount => contractAmount - retentionAmount;
  double get totalConnectedLoadVA => applianceLoads.fold(0.0, (sum, item) => sum + item.totalVA);
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
}
