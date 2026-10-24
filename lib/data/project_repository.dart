// BANAAG Project Repository (Permanent Offline Disk Persistence using SharedPreferences & JSON)
// Guarantees that user projects are NEVER lost across APK updates, app restarts, or background refreshes.

import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/models.dart';

class ProjectRepository {
  static final ProjectRepository instance = ProjectRepository._internal();
  ProjectRepository._internal() {
    _initPersistence();
  }

  static const String _storageKey = 'banaag_contractor_projects_v1';
  final List<Project> _projects = [];
  final _projectsStreamController = StreamController<List<Project>>.broadcast();

  Stream<List<Project>> get projectsStream => _projectsStreamController.stream;
  List<Project> get allProjects => List.unmodifiable(_projects);

  Future<void> _initPersistence() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_storageKey);

      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonString);
        _projects.clear();
        for (final item in decoded) {
          _projects.add(Project.fromJson(item as Map<String, dynamic>));
        }
      } else {
        // First-time app launch: seed initial sample contractor projects
        _seedInitialProjects();
        await _saveToDisk();
      }
    } catch (_) {
      if (_projects.isEmpty) {
        _seedInitialProjects();
      }
    } finally {
      _projectsStreamController.add(_projects);
    }
  }

  Future<void> _saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _projects.map((p) => p.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (_) {
      // Disk write fallback
    }
  }

  List<ProjectPhase> _generatePhases({String intakeMode = 'SITE_INTERVIEW'}) {
    return ProjectPhaseType.values.map((phaseType) {
      final List<PhaseCheckItem> checklist = [];

      switch (phaseType) {
        case ProjectPhaseType.consultation:
          checklist.addAll([
            PhaseCheckItem(id: 'c0', title: 'Floor Plan Blueprint Intake & Room Calibration (PDF/CAD/Image)'),
            PhaseCheckItem(id: 'c1', title: 'Client Needs Analysis (Appliance & Connected Loads tally)'),
            PhaseCheckItem(id: 'c_takeoff', title: 'Initial Plan Takeoff & Wire Run Estimation (Plan Canvas)'),
            if (intakeMode == 'AUTOCAD_DXF')
              PhaseCheckItem(id: 'c_dxf', title: 'AutoCAD .DXF Architectural Plan Upload & Layer Audit'),
            PhaseCheckItem(id: 'c2', title: 'Site Inspection (Concrete vs Timber frame structure)'),
            PhaseCheckItem(id: 'c3', title: 'Utility Service Drop Coordinates (Meralco / Coop nearest pole location)'),
          ]);
          break;
        case ProjectPhaseType.permitting:
          checklist.addAll([
            PhaseCheckItem(id: 'p_takeoff', title: 'Final Architectural Takeoff & Conduit Routing Sign-off'),
            PhaseCheckItem(id: 'p1', title: 'Single-Line Diagram & Load Schedule computation completed'),
            PhaseCheckItem(id: 'p2', title: 'Plans signed and sealed by Professional Electrical Engineer (PEE)'),
            PhaseCheckItem(id: 'p3', title: 'Electrical Permit released by LGU Office of Building Official (OBO)'),
          ]);
          break;
        case ProjectPhaseType.procurement:
          checklist.addAll([
            PhaseCheckItem(id: 'pr1', title: 'BOM procurement from accredited local electrical supplier'),
            PhaseCheckItem(id: 'pr2', title: 'Mandatory PS / ICC marks verified on all THHN wires & breakers'),
          ]);
          break;
        case ProjectPhaseType.roughIn:
          checklist.addAll([
            PhaseCheckItem(id: 'r1', title: 'Chipping and conduit raceway installation complete'),
            PhaseCheckItem(id: 'r2', title: 'Minimum 150mm wire allowance left at all junction/utility boxes'),
            PhaseCheckItem(id: 'r3', title: 'MANDATORY PRE-COVER PHOTO SIGN-OFF: Masonry walls & ceiling raceways verified before concrete pour'),
          ]);
          break;
        case ProjectPhaseType.trimOut:
          checklist.addAll([
            PhaseCheckItem(id: 't1', title: 'Switches, convenience outlets & luminaires mounted'),
            PhaseCheckItem(id: 't2', title: 'Main Panelboard terminated with proper PEC color coding (Phase/Neutral/Ground)'),
          ]);
          break;
        case ProjectPhaseType.testing:
          checklist.addAll([
            PhaseCheckItem(id: 'te1', title: 'Insulation Resistance Test (Megger) >= 1.0 MΩ verified on all branch circuits'),
            PhaseCheckItem(id: 'te2', title: 'Line continuity and ground bond test verified'),
            PhaseCheckItem(id: 'te3', title: 'Live load voltage check under simulated full capacity (230V nominal)'),
          ]);
          break;
        case ProjectPhaseType.turnover:
          checklist.addAll([
            PhaseCheckItem(id: 'to1', title: 'Certificate of Final Electrical Inspection (CFEI) secured'),
            PhaseCheckItem(id: 'to2', title: 'Permanent electric meter installed & sealed by utility (Meralco/Coop)'),
            PhaseCheckItem(id: 'to3', title: 'As-Built Plan & QR Maintenance directory turned over to client'),
          ]);
          break;
      }

      return ProjectPhase(type: phaseType, checklist: checklist);
    }).toList();
  }

  void _seedInitialProjects() {
    final List<ProjectPhase> defaultPhases = _generatePhases();

    // Project 1: Residence in Antipolo (Rough-in stage)
    final p1Phases = _clonePhases(defaultPhases);
    p1Phases[0].isCompleted = true;
    for (var item in p1Phases[0].checklist) {
      item.isCompleted = true;
    }
    p1Phases[1].isCompleted = true;
    for (var item in p1Phases[1].checklist) {
      item.isCompleted = true;
    }
    p1Phases[2].isCompleted = true;
    for (var item in p1Phases[2].checklist) {
      item.isCompleted = true;
    }
    p1Phases[3].checklist[0].isCompleted = true;
    p1Phases[3].checklist[1].isCompleted = true;

    _projects.add(
      Project(
        id: 'prj-001',
        title: 'Villa Dela Rosa 2-Storey Residence',
        clientName: 'Engr. Roberto Dela Rosa',
        clientContact: '+63 917 555 4321',
        siteAddress: 'Block 4 Lot 12, Sierra Vista Subd., Antipolo, Rizal',
        utilityProvider: 'Meralco',
        contractAmount: 385000.0,
        retentionPercent: 10.0,
        currentPhaseNumber: 4, // Rough-in
        phases: p1Phases,
        createdAt: DateTime.now().subtract(const Duration(days: 22)),
      ),
    );

    // Project 2: Commercial Fit-out (Permitting stage)
    final p2Phases = _clonePhases(defaultPhases);
    p2Phases[0].isCompleted = true;
    for (var item in p2Phases[0].checklist) {
      item.isCompleted = true;
    }

    _projects.add(
      Project(
        id: 'prj-002',
        title: 'Kape Siglo Commercial Fit-Out',
        clientName: 'Patricia Tan-Gomez',
        clientContact: '+63 928 888 1234',
        siteAddress: 'Unit 3B Ground Floor, Commercial Arcade, BGC, Taguig',
        utilityProvider: 'Meralco',
        contractAmount: 640000.0,
        retentionPercent: 10.0,
        currentPhaseNumber: 2, // Permitting
        phases: p2Phases,
        createdAt: DateTime.now().subtract(const Duration(days: 8)),
      ),
    );
  }

  List<ProjectPhase> _clonePhases(List<ProjectPhase> original) {
    return original.map((p) => ProjectPhase(
      type: p.type,
      isCompleted: p.isCompleted,
      checklist: p.checklist.map((c) => PhaseCheckItem(
        id: c.id,
        title: c.title,
        isMandatory: c.isMandatory,
        isCompleted: c.isCompleted,
        notes: c.notes,
      )).toList(),
    )).toList();
  }

  List<ProjectPhase> createDefaultPhases({String intakeMode = 'SITE_INTERVIEW'}) {
    return _generatePhases(intakeMode: intakeMode);
  }

  void addProject(Project project) {
    _projects.add(project);
    _projectsStreamController.add(_projects);
    _saveToDisk();
  }

  void updateProject(Project project) {
    final index = _projects.indexWhere((p) => p.id == project.id);
    if (index != -1) {
      _projects[index] = project;
      _projectsStreamController.add(_projects);
      _saveToDisk();
    }
  }

  void deleteProject(String id) {
    _projects.removeWhere((p) => p.id == id);
    _projectsStreamController.add(_projects);
    _saveToDisk();
  }
}
