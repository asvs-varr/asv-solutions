// BANAAG 7-Stage Workflow Screen with Pre-Cover Rough-In Photo Gate & Megger Log

import 'package:flutter/material.dart';
import '../../domain/models.dart';
import '../../data/project_repository.dart';
import '../theme/banaag_theme.dart';
import 'client_needs_analysis_screen.dart';
import '../widgets/project_management_dialogs.dart';
import '../widgets/dxf_export_guide_dialog.dart';

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
            'Bago mag-upload ng plano sa Stage 2 (Plan Takeoff), siguraduhing sumunod ang CAD file sa EXPLODE, AUDIT, at standard layer naming conventions.',
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
    return ListTile(
      dense: true,
      enabled: !isLocked,
      onTap: item.id == 'c1' && !isLocked
          ? () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClientNeedsAnalysisScreen(project: _project),
                ),
              );
              setState(() {});
            }
          : null,
      leading: Checkbox(
        value: item.isCompleted,
        activeColor: BanaagTheme.primaryAmber,
        checkColor: Colors.black,
        onChanged: isLocked ? null : (_) => _toggleCheckItem(phase, item),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              item.title,
              style: TextStyle(
                fontSize: 13,
                decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                color: item.isCompleted
                    ? BanaagTheme.textMuted
                    : (item.id == 'c1' ? BanaagTheme.primaryAmber : BanaagTheme.textHighEmphasis),
                fontWeight: item.id == 'c1' ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (item.id == 'c1' && !isLocked)
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: BanaagTheme.primaryAmber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('OPEN TALLY ➔', style: TextStyle(color: BanaagTheme.primaryAmber, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      trailing: item.id == 'r3' // Rough-in mandatory photo proof
          ? IconButton(
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
                  const SnackBar(content: Text('📸 Pre-cover rough-in photo proof saved & verified!')),
                );
              },
            )
          : null,
    );
  }
}
