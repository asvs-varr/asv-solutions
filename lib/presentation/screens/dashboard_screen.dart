// BANAAG Dashboard Screen: Gesture-First Quick-Tap Command Center

import 'package:flutter/material.dart';
import '../../domain/models.dart';
import '../../data/project_repository.dart';
import '../theme/banaag_theme.dart';
import 'pec_calculator_screen.dart';
import 'workflow_screen.dart';
import 'plan_canvas_screen.dart';
import 'commercial_suite_screen.dart';
import 'future_proofing_screen.dart';
import 'banaag_pro_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final repo = ProjectRepository.instance;

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

                // Active Projects List
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Active Electrical Projects', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 16, color: BanaagTheme.primaryAmber),
                      label: const Text('New Project', style: TextStyle(color: BanaagTheme.primaryAmber, fontWeight: FontWeight.bold)),
                      onPressed: () => _showNewProjectDialog(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                ...projects.map((project) => _buildProjectCard(project)),
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
                ],
              ),
              const SizedBox(height: 6),
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
                  Text('Stage: ${currentPhase.type.title}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
                    'Pumili ng Project Intake Mode (Batay sa sitwasyon sa Site):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: BanaagTheme.primaryAmber),
                  ),
                ),
                const SizedBox(height: 8),
                _buildIntakeModeCard(
                  title: '🗣️ Fast Site Interview Mode',
                  subtitle: 'Walang plano / Maliit na bahay. Mabilisang interview sa may-ari; kusa nang magsu-suggest ang PEC package.',
                  modeKey: 'SITE_INTERVIEW',
                  currentMode: intakeMode,
                  onSelect: (m) => setDialogState(() => intakeMode = m),
                ),
                const SizedBox(height: 6),
                _buildIntakeModeCard(
                  title: '📸 Blueprint Picture Calibration',
                  subtitle: 'May dalang papel na plano. Kunan ng camera sa site at i-tag ang kwarto gamit ang Type Box.',
                  modeKey: 'BLUEPRINT_PHOTO',
                  currentMode: intakeMode,
                  onSelect: (m) => setDialogState(() => intakeMode = m),
                ),
                const SizedBox(height: 6),
                _buildIntakeModeCard(
                  title: '📐 AutoCAD .DXF Direct Import',
                  subtitle: 'May CAD file mula sa arkitekto. 1-click auto-detect ng pader, text, at electrical layout.',
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
              child: const Text('Create Project', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  phases: repo.createDefaultPhases(),
                  createdAt: DateTime.now(),
                );

                repo.addProject(newProject);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('⚡ New project "${newProject.title}" successfully created (${newProject.intakeMode})!')),
                );
              },
            ),
          ],
        ),
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
