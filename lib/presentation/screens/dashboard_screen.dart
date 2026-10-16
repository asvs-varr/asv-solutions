// BANAAG Dashboard Screen: Gesture-First Quick-Tap Command Center

import 'package:flutter/material.dart';
import '../../domain/models.dart';
import '../../data/project_repository.dart';
import '../theme/banaag_theme.dart';
import 'pec_calculator_screen.dart';
import 'workflow_screen.dart';
import 'plan_canvas_screen.dart';
import 'commercial_suite_screen.dart';

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
            icon: const Icon(Icons.shield_outlined, color: BanaagTheme.primaryAmber),
            tooltip: 'PS/ICC Material Shield',
            onPressed: () => _showMaterialShieldDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
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
                    TextButton(
                      child: const Text('New Project +', style: TextStyle(color: BanaagTheme.primaryAmber)),
                      onPressed: () {},
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
                  Text('₱${project.contractAmount.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: BanaagTheme.successGreen, fontSize: 13)),
                ],
              ),
            ],
          ),
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
