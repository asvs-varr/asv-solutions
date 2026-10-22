// BANAAG Project Edit & Management Dialogs (Edit, Archive, Delete with PIN/'DELETE' Safety Guard)

import 'package:flutter/material.dart';
import '../../domain/models.dart';
import '../../data/project_repository.dart';
import '../theme/banaag_theme.dart';

class ProjectManagementDialogs {
  /// Opens full Project Edit Dialog allowing modification of all project metadata & financials
  static void showEditProjectDialog(BuildContext context, Project project, {VoidCallback? onProjectUpdated}) {
    final titleController = TextEditingController(text: project.title);
    final clientController = TextEditingController(text: project.clientName);
    final contactController = TextEditingController(text: project.clientContact);
    final addressController = TextEditingController(text: project.siteAddress);
    final budgetController = TextEditingController(
      text: project.contractAmount > 0 ? project.contractAmount.toStringAsFixed(0) : '',
    );
    final retentionController = TextEditingController(text: project.retentionPercent.toStringAsFixed(0));
    String utility = project.utilityProvider;
    String intakeMode = project.intakeMode;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: BanaagTheme.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.edit_note, color: BanaagTheme.primaryAmber, size: 28),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Modify Project Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: BanaagTheme.textMuted, size: 20),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Project Name / Scope',
                    labelStyle: TextStyle(color: BanaagTheme.textMuted),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: clientController,
                        decoration: const InputDecoration(
                          labelText: 'Client Name',
                          labelStyle: TextStyle(color: BanaagTheme.textMuted),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: contactController,
                        decoration: const InputDecoration(
                          labelText: 'Contact / Phone',
                          labelStyle: TextStyle(color: BanaagTheme.textMuted),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Site Address',
                    labelStyle: TextStyle(color: BanaagTheme.textMuted),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: budgetController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Contract / Budget (₱)',
                          hintText: 'e.g. 150000',
                          labelStyle: TextStyle(color: BanaagTheme.textMuted),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: retentionController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Retention %',
                          suffixText: '%',
                          labelStyle: TextStyle(color: BanaagTheme.textMuted),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: utility,
                  dropdownColor: BanaagTheme.surfaceCard,
                  decoration: const InputDecoration(
                    labelText: 'Utility Provider',
                    labelStyle: TextStyle(color: BanaagTheme.textMuted),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Meralco', child: Text('Meralco')),
                    DropdownMenuItem(value: 'CANORECO', child: Text('CANORECO')),
                    DropdownMenuItem(value: 'BATELEC II', child: Text('BATELEC II')),
                    DropdownMenuItem(value: 'Electric Coop (Provincial)', child: Text('Electric Coop (Provincial)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => utility = val);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: intakeMode,
                  dropdownColor: BanaagTheme.surfaceCard,
                  decoration: const InputDecoration(
                    labelText: 'Intake Method Mode',
                    labelStyle: TextStyle(color: BanaagTheme.textMuted),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'SITE_INTERVIEW', child: Text('🗣️ Site Interview Mode')),
                    DropdownMenuItem(value: 'BLUEPRINT_PHOTO', child: Text('📸 Blueprint Photo Calibration')),
                    DropdownMenuItem(value: 'AUTOCAD_DXF', child: Text('📐 AutoCAD .DXF Import')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => intakeMode = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: BanaagTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(120, 44),
                backgroundColor: BanaagTheme.primaryAmber,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                final newTitle = titleController.text.trim();
                if (newTitle.isEmpty) return;

                final newAmount = double.tryParse(budgetController.text.trim()) ?? 0.0;
                final newRetention = double.tryParse(retentionController.text.trim()) ?? 10.0;

                final updatedProject = Project(
                  id: project.id,
                  title: newTitle,
                  clientName: clientController.text.trim().isEmpty ? 'Walk-in Client' : clientController.text.trim(),
                  clientContact: contactController.text.trim().isEmpty ? '+63 9XX XXX XXXX' : contactController.text.trim(),
                  siteAddress: addressController.text.trim().isEmpty ? 'Philippines' : addressController.text.trim(),
                  utilityProvider: utility,
                  contractAmount: newAmount,
                  retentionPercent: newRetention,
                  currentPhaseNumber: project.currentPhaseNumber,
                  intakeMode: intakeMode,
                  isArchived: project.isArchived,
                  applianceLoads: project.applianceLoads,
                  canvasPoints: project.canvasPoints,
                  conduitRoutes: project.conduitRoutes,
                  phases: project.phases,
                  createdAt: project.createdAt,
                );

                ProjectRepository.instance.updateProject(updatedProject);
                Navigator.pop(ctx);
                onProjectUpdated?.call();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('✅ Project "${updatedProject.title}" details successfully updated!')),
                );
              },
              child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  /// Toggles Archive / Restore status of the project
  static void toggleArchiveProject(BuildContext context, Project project, {VoidCallback? onStateChanged}) {
    final bool willArchive = !project.isArchived;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BanaagTheme.surfaceCard,
        title: Row(
          children: [
            Icon(willArchive ? Icons.archive_outlined : Icons.unarchive_outlined,
                color: willArchive ? BanaagTheme.warningOrange : BanaagTheme.successGreen),
            const SizedBox(width: 8),
            Text(willArchive ? 'Archive Project?' : 'Restore Project?', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          willArchive
              ? 'Ilalagay ang "${project.title}" sa Archived tab. Mananatili ang lahat ng Load Schedules, single-line diagram, at photos nito nang buo.'
              : 'Ibabalik ang "${project.title}" sa Active Projects list.',
          style: const TextStyle(fontSize: 13, color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: BanaagTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(110, 40),
              backgroundColor: willArchive ? BanaagTheme.warningOrange : BanaagTheme.successGreen,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              project.isArchived = willArchive;
              ProjectRepository.instance.updateProject(project);
              Navigator.pop(ctx);
              onStateChanged?.call();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(willArchive
                      ? '📦 Project "${project.title}" moved to Archived!'
                      : '⚡ Project "${project.title}" restored to Active Projects!'),
                ),
              );
            },
            child: Text(willArchive ? 'Archive' : 'Restore', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Shows high-safety Delete Confirmation dialog requiring typing 'DELETE' to eliminate accidental loss
  static void showSafeDeleteProjectDialog(BuildContext context, Project project, {VoidCallback? onDeleted}) {
    final confirmController = TextEditingController();
    bool canDelete = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: BanaagTheme.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: BanaagTheme.alertRed, size: 28),
              SizedBox(width: 8),
              Expanded(
                child: Text('Delete Project (Danger Zone)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: BanaagTheme.alertRed)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete "${project.title}"?',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                'All appliances, single-line computations, wire sizing takeoff, and inspection sign-offs for this project will be permanently lost.',
                style: TextStyle(color: BanaagTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              const Text(
                'To confirm and prevent accidental deletion, type "DELETE" below:',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: BanaagTheme.primaryAmber),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmController,
                autofocus: true,
                style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, color: BanaagTheme.alertRed),
                decoration: InputDecoration(
                  hintText: 'Type DELETE to confirm',
                  hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 0),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: BanaagTheme.alertRed)),
                ),
                onChanged: (val) {
                  setDialogState(() {
                    canDelete = val.trim().toUpperCase() == 'DELETE';
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: BanaagTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(120, 44),
                backgroundColor: canDelete ? BanaagTheme.alertRed : Colors.grey.shade800,
                foregroundColor: Colors.white,
              ),
              onPressed: canDelete
                  ? () {
                      ProjectRepository.instance.deleteProject(project.id);
                      Navigator.pop(ctx);
                      onDeleted?.call();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('🗑️ Project "${project.title}" permanently deleted.')),
                      );
                    }
                  : null,
              child: const Text('Delete Forever', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  /// Displays the 3-dot popup menu action bottom sheet or popup for a project
  static void showProjectActionSheet(BuildContext context, Project project, {VoidCallback? onRefresh}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: BanaagTheme.surfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: BanaagTheme.primaryAmber.withValues(alpha: 0.15),
                  child: const Icon(Icons.bolt, color: BanaagTheme.primaryAmber),
                ),
                title: Text(project.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${project.clientName} • Phase ${project.currentPhaseNumber}/7 • ${project.isArchived ? "Archived" : "Active"}'),
              ),
              const Divider(color: Colors.white12),
              ListTile(
                leading: const Icon(Icons.edit, color: BanaagTheme.primaryAmber),
                title: const Text('Modify / Edit Project Info'),
                subtitle: const Text('Change Title, Client details, Budget, Address, & Utility'),
                onTap: () {
                  Navigator.pop(ctx);
                  showEditProjectDialog(context, project, onProjectUpdated: onRefresh);
                },
              ),
              ListTile(
                leading: Icon(project.isArchived ? Icons.unarchive : Icons.archive_outlined,
                    color: project.isArchived ? BanaagTheme.successGreen : BanaagTheme.warningOrange),
                title: Text(project.isArchived ? 'Restore to Active Projects' : 'Archive Project'),
                subtitle: Text(project.isArchived ? 'Mark as ongoing active project' : 'Move project out of active dashboard view'),
                onTap: () {
                  Navigator.pop(ctx);
                  toggleArchiveProject(context, project, onStateChanged: onRefresh);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: BanaagTheme.alertRed),
                title: const Text('Delete Project', style: TextStyle(color: BanaagTheme.alertRed, fontWeight: FontWeight.bold)),
                subtitle: const Text('Permanent removal with safety confirmation', style: TextStyle(color: Colors.redAccent, fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  showSafeDeleteProjectDialog(context, project, onDeleted: onRefresh);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
