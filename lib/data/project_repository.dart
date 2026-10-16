// BANAAG Project Repository (In-Memory Offline Cache with Realistic Philippine Contractor Data)

import 'dart:async';
import '../domain/models.dart';

class ProjectRepository {
  static final ProjectRepository instance = ProjectRepository._internal();
  ProjectRepository._internal() {
    _seedInitialProjects();
  }

  final List<Project> _projects = [];
  final _projectsStreamController = StreamController<List<Project>>.broadcast();

  Stream<List<Project>> get projectsStream => _projectsStreamController.stream;
  List<Project> get allProjects => List.unmodifiable(_projects);

  void _seedInitialProjects() {
    final List<ProjectPhase> defaultPhases = ProjectPhaseType.values.map((phaseType) {
      final List<PhaseCheckItem> checklist = [];

      switch (phaseType) {
        case ProjectPhaseType.consultation:
          checklist.addAll([
            PhaseCheckItem(id: 'c1', title: 'Client Needs Analysis (Appliance & Connected Loads tally)'),
            PhaseCheckItem(id: 'c2', title: 'Site Inspection (Concrete vs Timber frame structure)'),
            PhaseCheckItem(id: 'c3', title: 'Utility Service Drop Coordinates (Meralco / Coop nearest pole location)'),
          ]);
          break;
        case ProjectPhaseType.permitting:
          checklist.addAll([
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
            PhaseCheckItem(id: 'r3', title: 'MANDATORY PRE-COVER PHOTO SIGN-OFF: Pader & Kisame verified before mason pour'),
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
            PhaseCheckItem(id: 'tu1', title: 'City / Municipal OBO Inspection passed & CEI certificate released'),
            PhaseCheckItem(id: 'tu2', title: 'Utility service connection & permanent meter installed'),
            PhaseCheckItem(id: 'tu3', title: 'As-Built drawings and panelboard safety orientation turned over to client'),
          ]);
          break;
      }

      return ProjectPhase(
        type: phaseType,
        isCompleted: false,
        checklist: checklist,
      );
    }).toList();

    // Seed Project 1: Residential 2-Storey (Currently in Rough-In Stage)
    final p1Phases = _clonePhases(defaultPhases);
    p1Phases[0].isCompleted = true; // Consultation
    for (final c in p1Phases[0].checklist) {
      c.isCompleted = true;
    }
    p1Phases[1].isCompleted = true; // Permitting
    for (final c in p1Phases[1].checklist) {
      c.isCompleted = true;
    }
    p1Phases[2].isCompleted = true; // Procurement
    for (final c in p1Phases[2].checklist) {
      c.isCompleted = true;
    }

    _projects.add(
      Project(
        id: 'PRJ-2026-001',
        title: '2-Storey Modern Residential Wiring',
        clientName: 'Engr. Marco Villanueva',
        clientContact: '+63 917 555 4321',
        siteAddress: 'Block 12 Lot 4, Grand Villas, Lipa City, Batangas',
        utilityProvider: 'BATELEC II',
        contractAmount: 385000.0,
        retentionPercent: 10.0,
        currentPhaseNumber: 4, // Rough-in
        phases: p1Phases,
        createdAt: DateTime.now().subtract(const Duration(days: 24)),
      ),
    );

    // Seed Project 2: Commercial Restaurant Fit-Out (Design Stage)
    final p2Phases = _clonePhases(defaultPhases);
    p2Phases[0].isCompleted = true;
    for (final c in p2Phases[0].checklist) {
      c.isCompleted = true;
    }

    _projects.add(
      Project(
        id: 'PRJ-2026-002',
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

    _projectsStreamController.add(_projects);
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

  List<ProjectPhase> createDefaultPhases() {
    return _clonePhases(_projects.first.phases.map((p) => ProjectPhase(
      type: p.type,
      isCompleted: false,
      checklist: p.checklist.map((c) => PhaseCheckItem(
        id: c.id,
        title: c.title,
        isMandatory: c.isMandatory,
        isCompleted: false,
        notes: c.notes,
      )).toList(),
    )).toList());
  }

  void addProject(Project project) {
    _projects.add(project);
    _projectsStreamController.add(_projects);
  }

  void updateProject(Project project) {
    final index = _projects.indexWhere((p) => p.id == project.id);
    if (index != -1) {
      _projects[index] = project;
      _projectsStreamController.add(_projects);
    }
  }
}
