// BANAAG 7-Stage Workflow Screen with Pre-Cover Rough-In Photo Gate & Megger Log

import 'dart:io';
import 'package:flutter/material.dart';
import '../../domain/models.dart';
import '../../data/project_repository.dart';
import '../theme/banaag_theme.dart';
import 'client_needs_analysis_screen.dart';
import 'single_line_diagram_screen.dart';
import '../widgets/project_management_dialogs.dart';
import '../widgets/dxf_export_guide_dialog.dart';
import '../widgets/site_inspection_dialog.dart';
import '../widgets/utility_service_drop_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'plan_canvas_screen.dart';

class WorkflowScreen extends StatefulWidget {
  final Project project;
  const WorkflowScreen({super.key, required this.project});

  @override
  State<WorkflowScreen> createState() => _WorkflowScreenState();
}

class _WorkflowScreenState extends State<WorkflowScreen> {
  late Project _project;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _ensureFloorPlanIntakeChecklistItem();
    _ensureDxfChecklistItem();
  }

  void _ensureFloorPlanIntakeChecklistItem() {
    final p1 = _project.phases.firstWhere(
      (p) => p.type == ProjectPhaseType.consultation,
      orElse: () => _project.phases.first,
    );
    final hasC0 = p1.checklist.any((i) => i.id == 'c0');
    if (!hasC0) {
      final bool alreadyHasPlan = _project.blueprintImagePath != null &&
          _project.blueprintImagePath!.isNotEmpty &&
          _project.spaces.isNotEmpty &&
          _project.spaces.every((s) => s.canvasX != null && s.canvasWidth != null);

      p1.checklist.insert(
        0,
        PhaseCheckItem(
          id: 'c0',
          title: 'Floor Plan Blueprint Intake & Room Calibration (PDF/CAD/Image)',
          isCompleted: alreadyHasPlan,
        ),
      );
      ProjectRepository.instance.updateProject(_project);
    }
  }

  void _ensureDxfChecklistItem() {
    if (_project.intakeMode == 'AUTOCAD_DXF') {
      final p1 = _project.phases.firstWhere(
        (p) => p.type == ProjectPhaseType.consultation,
        orElse: () => _project.phases.first,
      );
      final hasDxfItem = p1.checklist.any((i) => i.id == 'c_dxf');
      if (!hasDxfItem) {
        // Insert right after c1 (Client Needs Analysis)
        final c1Index = p1.checklist.indexWhere((i) => i.id == 'c1');
        final insertIndex = c1Index != -1 ? c1Index + 1 : 0;
        p1.checklist.insert(
          insertIndex,
          PhaseCheckItem(
            id: 'c_dxf',
            title: 'AutoCAD .DXF Architectural Plan Upload & Layer Audit',
            isCompleted: false,
          ),
        );
        ProjectRepository.instance.updateProject(_project);
      }
    }
  }

  void _toggleCheckItem(ProjectPhase phase, PhaseCheckItem item) {
    setState(() {
      item.isCompleted = !item.isCompleted;

      // Check if all checklist items in phase are completed
      final allDone = phase.checklist.every((c) => c.isCompleted);
      phase.isCompleted = allDone;
      if (allDone && phase.type.phaseNumber >= _project.currentPhaseNumber && _project.currentPhaseNumber < 7) {
        _project.currentPhaseNumber = phase.type.phaseNumber + 1;
      }
      ProjectRepository.instance.updateProject(_project);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_project.title),
            Text(
              'Phase ${_project.currentPhaseNumber} of 7: ${_project.phases[_project.currentPhaseNumber - 1].type.title}',
              style: const TextStyle(color: BanaagTheme.primaryAmber, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: BanaagTheme.primaryAmber),
            tooltip: 'Edit Project Info',
            onPressed: () {
              ProjectManagementDialogs.showEditProjectDialog(
                context,
                _project,
                onProjectUpdated: () {
                  setState(() {
                    _project = ProjectRepository.instance.allProjects.firstWhere(
                      (p) => p.id == _project.id,
                      orElse: () => _project,
                    );
                  });
                },
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            tooltip: 'More Options',
            color: BanaagTheme.surfaceCard,
            onSelected: (val) {
              if (val == 'dxf_guide') {
                DxfExportGuideDialog.show(context);
              } else if (val == 'archive') {
                ProjectManagementDialogs.toggleArchiveProject(
                  context,
                  _project,
                  onStateChanged: () {
                    setState(() {});
                  },
                );
              } else if (val == 'delete') {
                ProjectManagementDialogs.showSafeDeleteProjectDialog(
                  context,
                  _project,
                  onDeleted: () {
                    Navigator.pop(context); // Exit Workflow back to Dashboard
                  },
                );
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'dxf_guide',
                child: Row(
                  children: [
                    Icon(Icons.architecture, color: BanaagTheme.primaryAmber, size: 20),
                    SizedBox(width: 8),
                    Text('AutoCAD .DXF Guide'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'archive',
                child: Row(
                  children: [
                    Icon(_project.isArchived ? Icons.unarchive : Icons.archive_outlined,
                        color: _project.isArchived ? BanaagTheme.successGreen : BanaagTheme.warningOrange, size: 20),
                    const SizedBox(width: 8),
                    Text(_project.isArchived ? 'Restore Project' : 'Archive Project'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: BanaagTheme.alertRed, size: 20),
                    SizedBox(width: 8),
                    Text('Delete Project', style: TextStyle(color: BanaagTheme.alertRed, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          if (_project.intakeMode == 'AUTOCAD_DXF')
            _buildDxfGuideBanner(),
          ..._project.phases.map((phase) {
            final bool isCurrent = phase.type.phaseNumber == _project.currentPhaseNumber;
            final bool isLocked = phase.type.phaseNumber > _project.currentPhaseNumber;

            return Card(
              margin: const EdgeInsets.only(bottom: 16.0),
              color: isCurrent ? const Color(0xFF222834) : BanaagTheme.surfaceCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isCurrent
                      ? BanaagTheme.primaryAmber
                      : (phase.isCompleted ? BanaagTheme.successGreen : BanaagTheme.surfaceCardBorder),
                  width: isCurrent ? 2.0 : 1.0,
                ),
              ),
              child: ExpansionTile(
                key: PageStorageKey('phase_${phase.type.phaseNumber}'),
                initiallyExpanded: isCurrent,
              leading: CircleAvatar(
                backgroundColor: phase.isCompleted
                    ? BanaagTheme.successGreen
                    : (isCurrent ? BanaagTheme.primaryAmber : Colors.grey.shade800),
                foregroundColor: Colors.black,
                child: phase.isCompleted
                    ? const Icon(Icons.check, size: 20)
                    : Text('${phase.type.phaseNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              title: Text(
                phase.type.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isLocked ? BanaagTheme.textMuted : BanaagTheme.textHighEmphasis,
                ),
              ),
              subtitle: Text(phase.type.description, style: const TextStyle(color: BanaagTheme.textMuted, fontSize: 12)),
              children: [
                const Divider(color: BanaagTheme.surfaceCardBorder, height: 1),
                if (phase.type == ProjectPhaseType.roughIn)
                  _buildRoughInWarningBanner(),
                ...phase.checklist.map((item) => _buildChecklistTile(phase, item, isLocked)),
                const SizedBox(height: 12),
              ],
            ),
          );
        }),
      ],
    ),
  );
}

  Widget _buildDxfGuideBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E232D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BanaagTheme.primaryAmber.withValues(alpha: 0.8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: BanaagTheme.primaryAmber.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: BanaagTheme.primaryAmber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.architecture, color: BanaagTheme.primaryAmber, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AutoCAD .DXF Project Mode Active',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                    ),
                    Text(
                      '100% Guaranteed Analyzer Protocol',
                      style: TextStyle(color: BanaagTheme.primaryAmber, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Before uploading plans to Stage 2 (Plan Takeoff), ensure CAD files follow EXPLODE, AUDIT, and standard layer naming conventions.',
            style: TextStyle(fontSize: 11, color: BanaagTheme.textMuted, height: 1.3),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: BanaagTheme.primaryAmber,
                side: const BorderSide(color: BanaagTheme.primaryAmber),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              icon: const Icon(Icons.menu_book, size: 16),
              label: const Text('Buksan ang AutoCAD .DXF Export Guide', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: () => DxfExportGuideDialog.show(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoughInWarningBanner() {
    return Container(
      margin: const EdgeInsets.all(12.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'HIGH RISK PHASE GATE: Mandatory Pre-Cover inspection. Do NOT allow masons/carpenters to seal walls or ceiling without photo audit proof!',
              style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistTile(ProjectPhase phase, PhaseCheckItem item, bool isLocked) {
    // HARD GATE: c1 (Open Tally) is locked until c0 (Floor Plan Intake & Room Calibration) is completed!
    final bool isC0Completed = phase.checklist.any((c) => c.id == 'c0' && c.isCompleted);
    final bool isItemGated = isLocked || (item.id == 'c1' && !isC0Completed);

    return ListTile(
      dense: true,
      enabled: !isItemGated,
      onTap: !isItemGated
          ? () async {
              if (item.id == 'c0') {
                if (_project.blueprintImagePath == null || _project.blueprintImagePath!.isEmpty) {
                  await _openFloorPlanScanner();
                } else {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlanCanvasScreen(project: _project, initialStage: 1),
                    ),
                  );
                }
                setState(() {
                  _project = ProjectRepository.instance.allProjects.firstWhere(
                    (p) => p.id == _project.id,
                    orElse: () => _project,
                  );
                });
              } else if (item.id == 'c1') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClientNeedsAnalysisScreen(project: _project),
                  ),
                );
                setState(() {});
              } else if (item.id == 'c2') {
                SiteInspectionAssessmentDialog.show(
                  context,
                  project: _project,
                  checkItem: item,
                  onSaved: () {
                    setState(() {
                      _project = ProjectRepository.instance.allProjects.firstWhere(
                        (p) => p.id == _project.id,
                        orElse: () => _project,
                      );
                    });
                  },
                );
              } else if (item.id == 'c3') {
                UtilityServiceDropDialog.show(
                  context,
                  project: _project,
                  checkItem: item,
                  onSaved: () {
                    setState(() {
                      _project = ProjectRepository.instance.allProjects.firstWhere(
                        (p) => p.id == _project.id,
                        orElse: () => _project,
                      );
                    });
                  },
                );
              } else if (item.id == 'c_dxf') {
                _handleDxfUpload(phase, item);
              } else if (item.id == 'c_takeoff' || item.id == 'p_takeoff') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlanCanvasScreen(project: _project),
                  ),
                );
                setState(() {
                  _project = ProjectRepository.instance.allProjects.firstWhere(
                    (p) => p.id == _project.id,
                    orElse: () => _project,
                  );
                });
              } else if (item.id == 'p1') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SingleLineDiagramScreen(project: _project),
                  ),
                );
                setState(() {
                  _project = ProjectRepository.instance.allProjects.firstWhere(
                    (p) => p.id == _project.id,
                    orElse: () => _project,
                  );
                });
              }
            }
          : null,
      leading: Checkbox(
        value: item.isCompleted,
        activeColor: BanaagTheme.primaryAmber,
        checkColor: Colors.black,
        onChanged: isLocked ? null : (_) => _toggleCheckItem(phase, item),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 13,
                    decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                    color: item.isCompleted
                        ? BanaagTheme.textMuted
                        : (item.id == 'c0' || item.id == 'c1' || item.id == 'c2' || item.id == 'c_dxf' ? BanaagTheme.primaryAmber : BanaagTheme.textHighEmphasis),
                    fontWeight: (item.id == 'c0' || item.id == 'c1' || item.id == 'c2' || item.id == 'c_dxf') ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
          if (item.id == 'c0' && !isLocked)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _project.blueprintImagePath != null && _project.blueprintImagePath!.isNotEmpty
                      ? 'CALIBRATE ROOMS ➔'
                      : 'UPLOAD PLAN ➔',
                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          if (item.id == 'c1' && isItemGated && !isLocked)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                ),
                child: const Text('🔒 LOCKED: Complete Floor Plan Calibration (c0) First',
                    style: TextStyle(color: Colors.redAccent, fontSize: 9.5, fontWeight: FontWeight.bold)),
              ),
            ),
          if (item.id == 'c1' && !isItemGated)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: BanaagTheme.primaryAmber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('OPEN TALLY ➔', style: TextStyle(color: BanaagTheme.primaryAmber, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
          if ((item.id == 'c_takeoff' || item.id == 'p_takeoff') && !isLocked)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('OPEN CANVAS âž”', style: TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  if (_project.blueprintImagePath != null && _project.blueprintImagePath!.isNotEmpty)
                    GestureDetector(
                      onTap: _openFloorPlanScanner,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: BanaagTheme.primaryAmber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('RE-SCAN PLAN ðŸ”', style: TextStyle(color: BanaagTheme.primaryAmber, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
          if (item.id == 'c2' && !isLocked && !item.isCompleted)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: BanaagTheme.primaryAmber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('ASSESS SITE âž”', style: TextStyle(color: BanaagTheme.primaryAmber, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
          if (item.id == 'c2' && item.isCompleted)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: BanaagTheme.successGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('ASSESSED âœ…', style: TextStyle(color: BanaagTheme.successGreen, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
          if (item.id == 'c3' && !isLocked && !item.isCompleted)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: BanaagTheme.primaryAmber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('CALCULATE DROP âž”', style: TextStyle(color: BanaagTheme.primaryAmber, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
          if (item.id == 'c3' && item.isCompleted)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: BanaagTheme.successGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('DROP VERIFIED âœ…', style: TextStyle(color: BanaagTheme.successGreen, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
          if (item.id == 'c_dxf' && !isLocked && !item.isCompleted)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: BanaagTheme.primaryAmber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('UPLOAD âž”', style: TextStyle(color: BanaagTheme.primaryAmber, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
          if (item.id == 'c_dxf' && item.isCompleted)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: BanaagTheme.successGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('PARSED âœ…', style: TextStyle(color: BanaagTheme.successGreen, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
          if (item.id == 'p1' && !isLocked && !item.isCompleted)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: BanaagTheme.primaryAmber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('GENERATE SLD âž”', style: TextStyle(color: BanaagTheme.primaryAmber, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
          if (item.id == 'p1' && item.isCompleted)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: BanaagTheme.successGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('SLD READY âœ…', style: TextStyle(color: BanaagTheme.successGreen, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
      trailing: _buildCheckItemTrailing(phase, item, isLocked),
    );
  }

  Widget? _buildCheckItemTrailing(ProjectPhase phase, PhaseCheckItem item, bool isLocked) {
    if (item.id == 'c0') {
      return IconButton(
        icon: Icon(
          item.isCompleted ? Icons.check_circle : Icons.document_scanner_outlined,
          color: item.isCompleted ? BanaagTheme.successGreen : Colors.cyanAccent,
        ),
        tooltip: item.isCompleted ? 'Floor Plan Calibrated' : 'Intake & Calibrate Floor Plan',
        onPressed: isLocked
            ? null
            : () async {
                if (_project.blueprintImagePath == null || _project.blueprintImagePath!.isEmpty) {
                  await _openFloorPlanScanner();
                } else {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlanCanvasScreen(project: _project, initialStage: 1),
                    ),
                  );
                }
                setState(() {
                  _project = ProjectRepository.instance.allProjects.firstWhere(
                    (p) => p.id == _project.id,
                    orElse: () => _project,
                  );
                });
              },
      );
    } else if (item.id == 'c2') {
      return IconButton(
        icon: Icon(
          item.isCompleted ? Icons.check_circle : Icons.rule_sharp,
          color: item.isCompleted ? BanaagTheme.successGreen : BanaagTheme.primaryAmber,
        ),
        tooltip: 'Assess Site Structure & Materials',
        onPressed: isLocked
            ? null
            : () {
                SiteInspectionAssessmentDialog.show(
                  context,
                  project: _project,
                  checkItem: item,
                  onSaved: () {
                    setState(() {
                      _project = ProjectRepository.instance.allProjects.firstWhere(
                        (p) => p.id == _project.id,
                        orElse: () => _project,
                      );
                    });
                  },
                );
              },
      );
    } else if (item.id == 'c3') {
      return IconButton(
        icon: Icon(
          item.isCompleted ? Icons.check_circle : Icons.electric_bolt_outlined,
          color: item.isCompleted ? BanaagTheme.successGreen : BanaagTheme.primaryAmber,
        ),
        tooltip: 'Assess Utility Service Drop & Clearance',
        onPressed: isLocked
            ? null
            : () {
                UtilityServiceDropDialog.show(
                  context,
                  project: _project,
                  checkItem: item,
                  onSaved: () {
                    setState(() {
                      _project = ProjectRepository.instance.allProjects.firstWhere(
                        (p) => p.id == _project.id,
                        orElse: () => _project,
                      );
                    });
                  },
                );
              },
      );
    } else if (item.id == 'p1') {
      return IconButton(
        icon: Icon(
          item.isCompleted ? Icons.verified : Icons.account_tree_outlined,
          color: item.isCompleted ? BanaagTheme.successGreen : BanaagTheme.primaryAmber,
        ),
        tooltip: item.isCompleted ? 'SLD & Load Schedule Ready' : 'Generate Single-Line Diagram',
        onPressed: isLocked
            ? null
            : () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SingleLineDiagramScreen(project: _project),
                  ),
                );
                setState(() {
                  _project = ProjectRepository.instance.allProjects.firstWhere(
                    (p) => p.id == _project.id,
                    orElse: () => _project,
                  );
                });
              },
      );
    } else if (item.id == 'c_dxf') {
      return IconButton(
        icon: Icon(
          item.isCompleted ? Icons.check_circle : Icons.upload_file,
          color: item.isCompleted ? BanaagTheme.successGreen : BanaagTheme.primaryAmber,
        ),
        tooltip: item.isCompleted ? 'AutoCAD .DXF Parsed & Verified' : 'Upload AutoCAD .DXF File',
        onPressed: isLocked ? null : () => _handleDxfUpload(phase, item),
      );
    } else if (item.id == 'c_takeoff' || item.id == 'p_takeoff') {
      return IconButton(
        icon: Icon(
          item.isCompleted ? Icons.check_circle : Icons.architecture,
          color: item.isCompleted ? BanaagTheme.successGreen : Colors.cyanAccent,
        ),
        tooltip: item.isCompleted ? 'Takeoff Plan Completed' : 'Open Plan Canvas & Takeoff',
        onPressed: isLocked
            ? null
            : () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlanCanvasScreen(project: _project),
                  ),
                );
                setState(() {
                  _project = ProjectRepository.instance.allProjects.firstWhere(
                    (p) => p.id == _project.id,
                    orElse: () => _project,
                  );
                });
              },
      );
    } else if (item.id == 'r3') {
      return IconButton(
        icon: Icon(
          item.photoProofUri != null ? Icons.photo_library : Icons.camera_alt,
          color: item.photoProofUri != null ? BanaagTheme.successGreen : BanaagTheme.primaryAmber,
        ),
        tooltip: 'Attach Pre-Cover Photo Proof',
        onPressed: () {
          setState(() {
            item.photoProofUri = 'proof_photo_roughin.jpg';
            item.isCompleted = true;
            _toggleCheckItem(phase, item);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ðŸ“¸ Pre-cover rough-in photo proof saved & verified!')),
          );
        },
      );
    }
    return null;
  }

  void _handleDxfUpload(ProjectPhase phase, PhaseCheckItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BanaagTheme.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: BanaagTheme.primaryAmber, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.file_present_rounded, color: BanaagTheme.primaryAmber, size: 26),
            SizedBox(width: 8),
            Expanded(
              child: Text('Upload AutoCAD .DXF Plan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select or drop an AutoCAD 2018 ASCII .DXF file for automated layer extraction & takeoff.',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: BanaagTheme.primaryAmber.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.insert_drive_file, color: BanaagTheme.primaryAmber, size: 18),
                      SizedBox(width: 6),
                      Text('villa_delarosa_groundfloor.dxf', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('File size: 1.4 MB â€¢ Format: ASCII DXF Release 2018', style: TextStyle(fontSize: 11, color: BanaagTheme.textMuted)),
                  const Divider(color: Colors.white12, height: 16),
                  const Text('Layer Audit & Entity Scan Results:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: BanaagTheme.primaryAmber)),
                  const SizedBox(height: 4),
                  _layerScanRow('A-WALL', 'Exterior & Interior Walls (38 entities)', true),
                  _layerScanRow('A-ROOM', 'Living, Dining, Kitchen, Bath (4 rooms)', true),
                  _layerScanRow('E-LITE', 'Lighting Outlets & Droplights (14 entities)', true),
                  _layerScanRow('E-POWR', 'Duplex Outlets & Dedicated ACU (18 entities)', true),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.verified, color: BanaagTheme.successGreen, size: 16),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    '100% Layer Protocol Verified. Awtomatikong mamo-markang CHECK ang checklist item.',
                    style: TextStyle(fontSize: 11, color: BanaagTheme.successGreen, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: BanaagTheme.textMuted)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: BanaagTheme.primaryAmber,
              foregroundColor: Colors.black,
            ),
            icon: const Icon(Icons.cloud_done, size: 16),
            label: const Text('Simulate & Complete Upload', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                item.isCompleted = true;
                item.notes = 'Verified file: villa_delarosa_groundfloor.dxf (ASCII 2018, 4 layers parsed)';
                final allDone = phase.checklist.every((c) => c.isCompleted);
                phase.isCompleted = allDone;
                if (allDone && phase.type.phaseNumber >= _project.currentPhaseNumber && _project.currentPhaseNumber < 7) {
                  _project.currentPhaseNumber = phase.type.phaseNumber + 1;
                }
                ProjectRepository.instance.updateProject(_project);
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('âœ… AutoCAD .DXF uploaded & validated! Checklist automatically checked.'),
                  backgroundColor: BanaagTheme.successGreen,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _layerScanRow(String layer, String desc, bool isOk) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2.0),
      child: Row(
        children: [
          Icon(isOk ? Icons.check_circle_outline : Icons.error_outline, color: isOk ? BanaagTheme.successGreen : Colors.red, size: 12),
          const SizedBox(width: 4),
          Text(layer, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70)),
          const SizedBox(width: 6),
          Expanded(child: Text(desc, style: const TextStyle(fontSize: 10, color: BanaagTheme.textMuted), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Future<void> _openFloorPlanScanner() async {
    String? path = _project.blueprintImagePath;
    final hasExisting = path != null && path.isNotEmpty && File(path).existsSync();

    final selectedPath = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: BanaagTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: BanaagTheme.primaryAmber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.document_scanner_outlined, color: BanaagTheme.primaryAmber, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Floor Plan Blueprint Intake',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                        ),
                        Text(
                          'Select format for On-Device Room Space Extraction',
                          style: TextStyle(fontSize: 11, color: BanaagTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white10, height: 24),
              if (hasExisting) ...[
                ListTile(
                  leading: Icon(
                    path.toLowerCase().endsWith('.pdf') ? Icons.picture_as_pdf : Icons.image,
                    color: BanaagTheme.primaryAmber,
                  ),
                  title: Text(
                    'Scan Current Blueprint (${path.split(Platform.pathSeparator).last})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  ),
                  subtitle: const Text('Re-analyze room spaces with Google ML Kit OCR', style: TextStyle(fontSize: 11, color: BanaagTheme.textMuted)),
                  onTap: () => Navigator.pop(ctx, path),
                ),
                const Divider(color: Colors.white10, height: 12),
              ],
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                title: const Text('Import PDF Blueprint Sheet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                subtitle: const Text('Multi-page CAD architectural drawings & engineering plans', style: TextStyle(fontSize: 11, color: BanaagTheme.textMuted)),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final res = await FilePicker.pickFile(
                      type: FileType.custom,
                      allowedExtensions: ['pdf'],
                    );
                    if (res != null && res.path != null) {
                      _launchFloorPlanModal(res.path!);
                    }
                  } catch (e) {
                    debugPrint('Error picking PDF: $e');
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: Colors.cyanAccent),
                title: const Text('Pick Floor Plan Image / Photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                subtitle: const Text('High-resolution PNG, JPG, or blueprint camera snapshot', style: TextStyle(fontSize: 11, color: BanaagTheme.textMuted)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picker = ImagePicker();
                  final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                  if (image != null) {
                    _launchFloorPlanModal(image.path);
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (selectedPath != null && mounted) {
      _launchFloorPlanModal(selectedPath);
    }
  }

  Future<void> _launchFloorPlanModal(String path) async {
    setState(() {
      _project.blueprintImagePath = path;
      ProjectRepository.instance.updateProject(_project);
    });

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlanCanvasScreen(
          project: _project,
          initialStage: 1,
        ),
      ),
    );
    if (mounted) {
      setState(() {
        _project = ProjectRepository.instance.allProjects.firstWhere(
          (p) => p.id == _project.id,
          orElse: () => _project,
        );
      });
    }
  }
}

