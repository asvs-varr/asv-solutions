// BANAAG Commercial Suite Screen: Variation Orders, 10% Retention, Payroll, & Panel QR Card

import 'package:flutter/material.dart';
import '../../domain/models.dart';
import '../theme/banaag_theme.dart';

class CommercialSuiteScreen extends StatefulWidget {
  final Project project;
  const CommercialSuiteScreen({super.key, required this.project});

  @override
  State<CommercialSuiteScreen> createState() => _CommercialSuiteScreenState();
}

class _CommercialSuiteScreenState extends State<CommercialSuiteScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<VariationOrder> _variationOrders = [
    VariationOrder(
      id: 'VO-01',
      projectId: 'PRJ-2026-001',
      description: 'Add 3 Duplex CO in Lanai area & 1 Dedicated Circuit for Pressure Washer',
      additionalAmount: 8500.0,
      requestDate: DateTime.now().subtract(const Duration(days: 3)),
      isSignedByClient: true,
      signatureToken: 'ENG-MARCO-VILLANUEVA-SIG-OK',
    ),
    VariationOrder(
      id: 'VO-02',
      projectId: 'PRJ-2026-001',
      description: 'Upgrade standard switches to Smart WiFi Touch Dimmers (Living & Dining)',
      additionalAmount: 6200.0,
      requestDate: DateTime.now().subtract(const Duration(days: 1)),
      isSignedByClient: false,
    ),
  ];

  final List<ManpowerLog> _manpowerLogs = [
    ManpowerLog(id: 'm1', workerName: 'Jun-Jun Santos (RME)', role: 'Lead Electrician (RME)', dailyRate: 900.0, date: DateTime.now(), isPresent: true, overtimeHours: 2.0),
    ManpowerLog(id: 'm2', workerName: 'Danilo Cruz', role: 'Journeyman Electrician', dailyRate: 750.0, date: DateTime.now(), isPresent: true, overtimeHours: 1.0),
    ManpowerLog(id: 'm3', workerName: 'Arnel Mendoza', role: 'Electrician Helper', dailyRate: 550.0, date: DateTime.now(), isPresent: true, overtimeHours: 0.0),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('💼 Contractor Commercial Suite'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: BanaagTheme.primaryAmber,
          labelColor: BanaagTheme.primaryAmber,
          unselectedLabelColor: BanaagTheme.textMuted,
          tabs: const [
            Tab(text: 'Variation & Billing'),
            Tab(text: 'Site Payroll'),
            Tab(text: 'Panel QR Card'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBillingTab(),
          _buildPayrollTab(),
          _buildPanelQrTab(),
        ],
      ),
    );
  }

  Widget _buildBillingTab() {
    final double approvedAdditions = _variationOrders
        .where((vo) => vo.isSignedByClient)
        .fold(0.0, (sum, vo) => sum + vo.additionalAmount);

    final double adjustedContract = widget.project.contractAmount + approvedAdditions;
    final double retentionAmount = adjustedContract * 0.10; // 10% standard retention

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Financial Summary Card
          Card(
            color: const Color(0xFF1B2028),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _metricBadge('Original Contract', '₱${widget.project.contractAmount.toStringAsFixed(0)}'),
                      _metricBadge('Approved VO', '+₱${approvedAdditions.toStringAsFixed(0)}', color: BanaagTheme.successGreen),
                    ],
                  ),
                  const Divider(color: BanaagTheme.surfaceCardBorder, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _metricBadge('Total Adjusted Value', '₱${adjustedContract.toStringAsFixed(0)}'),
                      _metricBadge('10% Retention (Held)', '₱${retentionAmount.toStringAsFixed(0)}', color: BanaagTheme.warningOrange),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Variation Orders (Change Requests)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16, color: BanaagTheme.primaryAmber),
                label: const Text('Add VO', style: TextStyle(color: BanaagTheme.primaryAmber)),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 8),

          ..._variationOrders.map((vo) => _buildVoCard(vo)),
        ],
      ),
    );
  }

  Widget _buildVoCard(VariationOrder vo) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(vo.id, style: const TextStyle(color: BanaagTheme.primaryAmber, fontWeight: FontWeight.bold)),
                Text('+₱${vo.additionalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: BanaagTheme.successGreen)),
              ],
            ),
            const SizedBox(height: 8),
            Text(vo.description, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      vo.isSignedByClient ? Icons.check_circle : Icons.pending,
                      color: vo.isSignedByClient ? BanaagTheme.successGreen : BanaagTheme.warningOrange,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      vo.isSignedByClient ? 'SIGNED BY CLIENT' : 'AWAITING CLIENT SIGN-OFF',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: vo.isSignedByClient ? BanaagTheme.successGreen : BanaagTheme.warningOrange,
                      ),
                    ),
                  ],
                ),
                if (!vo.isSignedByClient)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: BanaagTheme.primaryAmber,
                      side: const BorderSide(color: BanaagTheme.primaryAmber),
                    ),
                    icon: const Icon(Icons.draw, size: 16),
                    label: const Text('Sign on Screen', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      setState(() {
                        vo.isSignedByClient = true;
                        vo.signatureToken = 'CLIENT-APPROVED-NOW';
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✍️ Variation Order signed & formally locked!')),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayrollTab() {
    final double totalToday = _manpowerLogs.fold(0.0, (sum, log) => sum + log.computedPay);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: const Color(0xFF1B2028),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _metricBadge('Site Manpower Today', '${_manpowerLogs.length} Workers'),
                  _metricBadge('Today\'s Labor Cost', '₱${totalToday.toStringAsFixed(0)}', color: BanaagTheme.primaryAmber),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Daily Attendance & Wage Tracker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ..._manpowerLogs.map((log) => ListTile(
                tileColor: BanaagTheme.surfaceCard,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: CircleAvatar(
                  backgroundColor: BanaagTheme.primaryAmber.withValues(alpha: 0.2),
                  foregroundColor: BanaagTheme.primaryAmber,
                  child: const Icon(Icons.person),
                ),
                title: Text(log.workerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${log.role} • ${log.overtimeHours > 0 ? '+${log.overtimeHours}h OT' : '8h Regular'}'),
                trailing: Text('₱${log.computedPay.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: BanaagTheme.primaryAmber)),
              )),
        ],
      ),
    );
  }

  Widget _buildPanelQrTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Center(
        child: Column(
          children: [
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
                      child: const Text('BANAAG SAFETY SYSTEM',
                          style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    const SizedBox(height: 16),
                    const Icon(Icons.qr_code_2, size: 140, color: Colors.black),
                    const SizedBox(height: 8),
                    const Text('SCAN FOR EMERGENCY ISOLATION MAP',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('Project: ${widget.project.title}', style: const TextStyle(color: Colors.black54, fontSize: 11)),
                    Text('Panel: LP-1 (230V 1-Phase 60Hz)', style: const TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.print),
              label: const Text('Print Panel Door Directory Sticker'),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('🖨️ Ready to print waterproof Panel Directory sticker!')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricBadge(String label, String value, {Color color = BanaagTheme.textHighEmphasis}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: BanaagTheme.textMuted, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
