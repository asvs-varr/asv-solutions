import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../domain/models.dart';
import '../../data/project_repository.dart';
import '../theme/banaag_theme.dart';
import 'pec_calculator_screen.dart';
import 'workflow_screen.dart';
import 'plan_canvas_screen.dart';
import 'commercial_suite_screen.dart';
import 'future_proofing_screen.dart';
import 'banaag_pro_screen.dart';
import '../widgets/project_management_dialogs.dart';
import '../widgets/dev_ticket_modal.dart';
import '../widgets/floor_plan_room_intake_modal.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final repo = ProjectRepository.instance;
  int _selectedProjectTab = 0; // 0 = Active, 1 = Archived

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.bolt, color: BanaagTheme.primaryAmber, size: 28),
            SizedBox(width: 8),
            Text('BANAAG', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.confirmation_number_outlined, color: BanaagTheme.primaryAmber),
            tooltip: 'Submit Dev Ticket / Issue',
            onPressed: () => showDevTicketSheet(context, projectContext: 'Dashboard'),
          ),
          IconButton(
            icon: const Icon(Icons.workspace_premium, color: BanaagTheme.primaryAmber),
            tooltip: 'BANAAG PRO Settings',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BanaagProScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.shield_outlined, color: BanaagTheme.primaryAmber),
            tooltip: 'PS/ICC Material Shield',
            onPressed: () => _showMaterialShieldDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<List<Project>>(
        stream: repo.projectsStream,
        initialData: repo.allProjects,
        builder: (context, snapshot) {
          final projects = snapshot.data ?? [];
          final double totalContractValue = projects.fold(0.0, (sum, p) => sum + p.contractAmount);
          final double totalRetention = projects.fold(0.0, (sum, p) => sum + p.retentionAmount);

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Financial Overview
                Card(
                  color: const Color(0xFF1B2028),
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _statBlock('Active Projects', '${projects.length}', Icons.apartment),
                            _statBlock('Total Value', '₱${(totalContractValue / 1000).toStringAsFixed(0)}k', Icons.payments, color: BanaagTheme.successGreen),
                            _statBlock('10% Retention', '₱${(totalRetention / 1000).toStringAsFixed(0)}k', Icons.lock_clock, color: BanaagTheme.warningOrange),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Quick-Tap Action Matrix
                const Text('One-Tap Operations Hub', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _quickActionTile(
                        icon: Icons.calculate_outlined,
                        title: 'PEC Engine',
                        subtitle: 'Wire, Pipe & Balancer',
                        color: BanaagTheme.primaryAmber,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PecCalculatorScreen())),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _quickActionTile(
                        icon: Icons.architecture,
                        title: 'Plan Takeoff',
                        subtitle: 'Canvas & Auto-BOM',
                        color: Colors.lightBlueAccent,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlanCanvasScreen())),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _quickActionTile(
                        icon: Icons.checklist_rtl,
                        title: '7-Stage QA',
                        subtitle: 'Pre-cover & Megger',
                        color: BanaagTheme.successGreen,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WorkflowScreen(project: projects.first))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _quickActionTile(
                        icon: Icons.electric_car,
                        title: 'Future-Proof',
                        subtitle: 'Solar, EV & IoT',
                        color: Colors.tealAccent,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FutureProofingScreen())),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _quickActionTile(
                        icon: Icons.request_quote_outlined,
                        title: 'Commercial',
                        subtitle: 'VO, Sign & Payroll',
                        color: Colors.purpleAccent,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CommercialSuiteScreen(project: projects.first))),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Projects Section Header with Active vs Archived Filter Tabs
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        ChoiceChip(
                          label: Text('Active (${projects.where((p) => !p.isArchived).length})'),
                          selected: _selectedProjectTab == 0,
                          selectedColor: BanaagTheme.primaryAmber,
                          backgroundColor: BanaagTheme.surfaceCard,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _selectedProjectTab == 0 ? Colors.black : Colors.white70,
                          ),
                          onSelected: (val) {
                            if (val) setState(() => _selectedProjectTab = 0);
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text('Archived (${projects.where((p) => p.isArchived).length})'),
                          selected: _selectedProjectTab == 1,
                          selectedColor: BanaagTheme.warningOrange,
                          backgroundColor: BanaagTheme.surfaceCard,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _selectedProjectTab == 1 ? Colors.black : Colors.white70,
                          ),
                          onSelected: (val) {
                            if (val) setState(() => _selectedProjectTab = 1);
                          },
                        ),
                      ],
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 16, color: BanaagTheme.primaryAmber),
                      label: const Text('New Project', style: TextStyle(color: BanaagTheme.primaryAmber, fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () => _showNewProjectDialog(context),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Render Filtered Projects or Empty State
                ...(() {
                  final filtered = projects.where((p) => _selectedProjectTab == 0 ? !p.isArchived : p.isArchived).toList();
                  if (filtered.isEmpty) {
                    return [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: BanaagTheme.surfaceCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: BanaagTheme.surfaceCardBorder),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _selectedProjectTab == 0 ? Icons.folder_open_outlined : Icons.archive_outlined,
                              size: 44,
                              color: BanaagTheme.textMuted,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _selectedProjectTab == 0
                                  ? 'Walang active electrical project sa ngayon.'
                                  : 'Walang naka-archive na project.',
                              style: const TextStyle(color: BanaagTheme.textMuted, fontSize: 13),
                            ),
                            if (_selectedProjectTab == 0) ...[
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(180, 40),
                                  backgroundColor: BanaagTheme.primaryAmber,
                                  foregroundColor: Colors.black,
                                ),
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Create First Project', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                onPressed: () => _showNewProjectDialog(context),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ];
                  }
                  return filtered.map((project) => _buildProjectCard(project)).toList();
                })(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statBlock(String label, String value, IconData icon, {Color color = BanaagTheme.primaryAmber}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: BanaagTheme.textMuted),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: BanaagTheme.textMuted, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _quickActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: BanaagTheme.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BanaagTheme.surfaceCardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.15),
              foregroundColor: color,
              child: Icon(icon, size: 20),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: BanaagTheme.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectCard(Project project) {
    final currentPhase = project.phases[project.currentPhaseNumber - 1];
    final double progressPercent = (project.currentPhaseNumber / 7.0);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WorkflowScreen(project: project))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(project.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: BanaagTheme.primaryAmber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Phase ${project.currentPhaseNumber}/7',
                      style: const TextStyle(color: BanaagTheme.primaryAmber, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, size: 20, color: BanaagTheme.textMuted),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Project Options',
                    onPressed: () => ProjectManagementDialogs.showProjectActionSheet(context, project),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text('${project.clientName} • ${project.utilityProvider}', style: const TextStyle(color: BanaagTheme.textMuted, fontSize: 12)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progressPercent,
                  backgroundColor: const Color(0xFF2C3240),
                  color: BanaagTheme.primaryAmber,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Stage: ${currentPhase.type.title}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    project.contractAmount > 0
                        ? '₱${project.contractAmount.toStringAsFixed(0)}'
                        : 'Pending Takeoff Estimate',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: project.contractAmount > 0 ? BanaagTheme.successGreen : BanaagTheme.warningOrange,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNewProjectDialog(BuildContext context) {
    final titleController = TextEditingController();
    final clientController = TextEditingController();
    final addressController = TextEditingController();
    final amountController = TextEditingController();
    String utility = 'Meralco';
    String intakeMode = 'SITE_INTERVIEW';
    String? selectedBlueprintPath;
    String? selectedBlueprintFileName;
    int? selectedBlueprintFileSize;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: BanaagTheme.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.add_business, color: BanaagTheme.primaryAmber),
              SizedBox(width: 8),
              Text('Create New Project', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Project Name / Scope',
                    hintText: 'e.g. 3-Storey Commercial Fit-Out',
                    labelStyle: TextStyle(color: BanaagTheme.textMuted),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: clientController,
                  decoration: const InputDecoration(
                    labelText: 'Client Name',
                    hintText: 'e.g. Arch. Roberto Ramos',
                    labelStyle: TextStyle(color: BanaagTheme.textMuted),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Site Address',
                    hintText: 'e.g. Barangay San Jose, Pasig City',
                    labelStyle: TextStyle(color: BanaagTheme.textMuted),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Client Target Budget (₱) - Optional',
                    hintText: 'Leave blank for Stage 2 Auto-BOM Takeoff',
                    labelStyle: TextStyle(color: BanaagTheme.textMuted),
                    helperText: 'Default: ₱0.00 (Auto-computes from Plan Layout Takeoff)',
                    helperStyle: TextStyle(color: Colors.amber, fontSize: 10),
                  ),
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
                    if (val != null) {
                      setDialogState(() => utility = val);
                    }
                  },
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Select Project Intake Mode (Based on Jobsite Availability):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: BanaagTheme.primaryAmber),
                  ),
                ),
                const SizedBox(height: 8),
                _buildIntakeModeCard(
                  title: '🗣️ Rapid Site Assessment & Interview',
                  subtitle: 'No architectural drawings / Small residential unit. Interactive client interview; automated PEC branch circuit recommendations.',
                  modeKey: 'SITE_INTERVIEW',
                  currentMode: intakeMode,
                  onSelect: (m) => setDialogState(() => intakeMode = m),
                ),
                const SizedBox(height: 6),
                _buildIntakeModeCard(
                  title: '📸 Blueprint Photo & Plan Takeoff',
                  subtitle: 'Physical paper blueprint available. Capture on-site or upload image to extract room boundaries & dimensional scaling.',
                  modeKey: 'BLUEPRINT_PHOTO',
                  currentMode: intakeMode,
                  onSelect: (m) => setDialogState(() => intakeMode = m),
                ),
                // Interactive File Upload Slot / Dropzone Card when Blueprint Photo is selected
                if (intakeMode == 'BLUEPRINT_PHOTO') ...[
                  const SizedBox(height: 10),
                  _buildBlueprintDropzoneCard(
                    filePath: selectedBlueprintPath,
                    fileName: selectedBlueprintFileName,
                    fileSize: selectedBlueprintFileSize,
                    onTakePhoto: () async {
                      try {
                        final picker = ImagePicker();
                        final XFile? photo = await picker.pickImage(
                          source: ImageSource.camera,
                          imageQuality: 92,
                        );
                        if (photo != null) {
                          final file = File(photo.path);
                          final size = await file.length();
                          setDialogState(() {
                            selectedBlueprintPath = photo.path;
                            selectedBlueprintFileName = photo.name.isNotEmpty
                                ? photo.name
                                : photo.path.split(Platform.pathSeparator).last;
                            selectedBlueprintFileSize = size;
                          });
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Camera error: $e'), backgroundColor: Colors.redAccent),
                          );
                        }
                      }
                    },
                    onPickFile: () async {
                      try {
                        final file = await FilePicker.pickFile(
                          type: FileType.custom,
                          allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
                        );
                        if (file != null && file.path != null) {
                          final size = file.lengthSync() ?? 0;
                          setDialogState(() {
                            selectedBlueprintPath = file.path;
                            selectedBlueprintFileName = file.name;
                            selectedBlueprintFileSize = size;
                          });
                        }
                      } catch (e) {
                        // Fallback to ImagePicker gallery
                        try {
                          final picker = ImagePicker();
                          final XFile? image = await picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 92,
                          );
                          if (image != null) {
                            final file = File(image.path);
                            final size = await file.length();
                            setDialogState(() {
                              selectedBlueprintPath = image.path;
                              selectedBlueprintFileName = image.name.isNotEmpty
                                  ? image.name
                                  : image.path.split(Platform.pathSeparator).last;
                              selectedBlueprintFileSize = size;
                            });
                          }
                        } catch (_) {}
                      }
                    },
                    onRemove: () {
                      setDialogState(() {
                        selectedBlueprintPath = null;
                        selectedBlueprintFileName = null;
                        selectedBlueprintFileSize = null;
                      });
                    },
                  ),
                ],
                const SizedBox(height: 6),
                _buildIntakeModeCard(
                  title: '📐 AutoCAD .DXF Vector Import',
                  subtitle: 'Architectural CAD drawing available. Automated layer parsing for walls, room boundaries, and electrical fixtures.',
                  modeKey: 'AUTOCAD_DXF',
                  currentMode: intakeMode,
                  onSelect: (m) => setDialogState(() => intakeMode = m),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: BanaagTheme.textMuted)),
              onPressed: () => Navigator.pop(ctx),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: BanaagTheme.primaryAmber,
                foregroundColor: Colors.black,
              ),
              child: Text(
                (intakeMode == 'BLUEPRINT_PHOTO' && selectedBlueprintPath != null)
                    ? 'Next: Calibrate & Tag Rooms →'
                    : 'Create Project',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                if (titleController.text.trim().isEmpty) return;
                final double contractAmt = double.tryParse(amountController.text.trim()) ?? 0.0;
                final newProject = Project(
                  id: 'PRJ-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
                  title: titleController.text.trim(),
                  clientName: clientController.text.trim().isEmpty ? 'Walk-in Client' : clientController.text.trim(),
                  clientContact: '+63 9XX XXX XXXX',
                  siteAddress: addressController.text.trim().isEmpty ? 'Philippines' : addressController.text.trim(),
                  utilityProvider: utility,
                  contractAmount: contractAmt,
                  retentionPercent: 10.0,
                  currentPhaseNumber: 1, // Starts at Consultation
                  intakeMode: intakeMode,
                  blueprintImagePath: selectedBlueprintPath,
                  phases: repo.createDefaultPhases(intakeMode: intakeMode),
                  createdAt: DateTime.now(),
                );

                Navigator.pop(ctx);

                if (intakeMode == 'BLUEPRINT_PHOTO' && selectedBlueprintPath != null) {
                  // Step 2: Open Floor Plan Calibration & Room Intake Modal
                  FloorPlanRoomIntakeModal.show(
                    context,
                    blueprintPath: selectedBlueprintPath!,
                    projectTitle: newProject.title,
                    onConfirmed: (scannedSpaces, lengthM, widthM) {
                      newProject.spaces = scannedSpaces;
                      newProject.roomGeometry = RoomGeometry(
                        roomType: 'RECTANGULAR',
                        leftWallMeters: widthM,
                        totalWidthMeters: lengthM,
                        cutoutWidthMeters: 0,
                        cutoutDepthMeters: 0,
                        rightWallMeters: widthM,
                      );
                      repo.addProject(newProject);
                      setState(() {});
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => WorkflowScreen(project: newProject)),
                      );
                    },
                  );
                } else {
                  // Fast creation: Save and go directly into project workflow
                  repo.addProject(newProject);
                  setState(() {});
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => WorkflowScreen(project: newProject)),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlueprintDropzoneCard({
    required String? filePath,
    required String? fileName,
    required int? fileSize,
    required VoidCallback onTakePhoto,
    required VoidCallback onPickFile,
    required VoidCallback onRemove,
  }) {
    final bool hasFile = filePath != null && filePath.isNotEmpty;
    final bool isPdf = hasFile && filePath.toLowerCase().endsWith('.pdf');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF131923),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasFile ? BanaagTheme.primaryAmber : const Color(0xFF384357),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasFile ? Icons.check_circle : Icons.cloud_upload_outlined,
                color: hasFile ? BanaagTheme.successGreen : BanaagTheme.primaryAmber,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Blueprint & Floor Plan Dropzone',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (hasFile ? BanaagTheme.successGreen : BanaagTheme.primaryAmber).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  hasFile ? 'READY' : 'ACTIVE SLOT',
                  style: TextStyle(
                    color: hasFile ? BanaagTheme.successGreen : BanaagTheme.primaryAmber,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (!hasFile) ...[
            const Text(
              'Kumuha ng litrato ng blueprint sa site o pumili mula sa gallery/PDF para mai-load agad sa Takeoff Canvas background.',
              style: TextStyle(fontSize: 11, color: BanaagTheme.textMuted, height: 1.3),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt, size: 15),
                    label: const Text('Take Photo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF283446),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: onTakePhoto,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.photo_library, size: 15),
                    label: const Text('Pick Blueprint', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BanaagTheme.primaryAmber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: onPickFile,
                  ),
                ),
              ],
            ),
          ] else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  if (isPdf)
                    Container(
                      height: 90,
                      width: double.infinity,
                      color: const Color(0xFF1E2634),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 36),
                          SizedBox(height: 4),
                          Text('PDF Blueprint Document', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  else
                    Image.file(
                      File(filePath),
                      height: 110,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, error, stackTrace) => Container(
                        height: 90,
                        color: Colors.black26,
                        child: const Center(
                          child: Icon(Icons.broken_image, color: Colors.white38),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'PREVIEW',
                        style: TextStyle(color: BanaagTheme.primaryAmber, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName ?? filePath.split(Platform.pathSeparator).last,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${fileSize != null ? (fileSize / (1024 * 1024)).toStringAsFixed(2) : "0"} MB • Ready for Canvas Underlay',
                        style: const TextStyle(color: BanaagTheme.successGreen, fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.replay, size: 14, color: BanaagTheme.primaryAmber),
                  label: const Text('Replace', style: TextStyle(color: BanaagTheme.primaryAmber, fontSize: 11)),
                  onPressed: onPickFile,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: BanaagTheme.alertRed),
                  tooltip: 'Remove',
                  onPressed: onRemove,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIntakeModeCard({
    required String title,
    required String subtitle,
    required String modeKey,
    required String currentMode,
    required ValueChanged<String> onSelect,
  }) {
    final bool isSelected = currentMode == modeKey;
    return InkWell(
      onTap: () => onSelect(modeKey),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2B220C) : const Color(0xFF161A22),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? BanaagTheme.primaryAmber : Colors.white12,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? BanaagTheme.primaryAmber : Colors.white38,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isSelected ? BanaagTheme.primaryAmber : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: BanaagTheme.textMuted, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMaterialShieldDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shield, color: BanaagTheme.primaryAmber),
            SizedBox(width: 8),
            Text('BPS / PS / ICC Shield'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Legitimate Certified Cable Brands in PH:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text('• Phelps Dodge Phils.\n• Columbia Wires & Cables\n• Philflex\n• American Wires\n• Royu / Meiji / Schneider'),
            SizedBox(height: 12),
            Text('Anti-Counterfeit Check:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
            Text('1. Magnet Test: Authentic copper is non-magnetic.\n2. Micrometer OD: #12 AWG must have full 3.5 mm² copper core, not just thick PVC.'),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('OK', style: TextStyle(color: BanaagTheme.primaryAmber)),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }
}
