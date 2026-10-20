// BANAAG PEC Calculator Screen: Wire Sizing, Conduit Fill, Voltage Drop & Smart Phase Balancer

import 'package:flutter/material.dart';
import '../../domain/pec_engine.dart';
import '../../domain/wiring_color_engine.dart';
import '../theme/banaag_theme.dart';

class PecCalculatorScreen extends StatefulWidget {
  const PecCalculatorScreen({super.key});

  @override
  State<PecCalculatorScreen> createState() => _PecCalculatorScreenState();
}

class _PecCalculatorScreenState extends State<PecCalculatorScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Wire & Conduit State
  double _loadCurrent = 24.0;
  int _conductorCount = 3;
  PecWireSpec _selectedWire = PecEngine.wireSpecs[1]; // 3.5 mm² default
  PecConduitSpec _selectedConduit = PecEngine.conduitSpecs[0]; // 20 mm default
  double _runLengthMeters = 25.0;

  // Phase Balancer State
  final List<Map<String, dynamic>> _circuits = [
    {'name': 'C1: Living Room Lights', 'loadVA': 450.0},
    {'name': 'C2: Master Bedroom CO', 'loadVA': 1200.0},
    {'name': 'C3: Kitchen Heavy Outlets', 'loadVA': 2500.0},
    {'name': 'C4: 2.0HP Split Aircon', 'loadVA': 2100.0},
    {'name': 'C5: 1.5HP Bedroom Aircon', 'loadVA': 1650.0},
    {'name': 'C6: Bathroom Water Heater', 'loadVA': 3500.0},
    {'name': 'C7: Dining & Terrace Lights', 'loadVA': 380.0},
    {'name': 'C8: Refrigerator Dedicated', 'loadVA': 800.0},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _recalculate();
  }

  void _recalculate() {
    _selectedWire = PecEngine.sizeWireForCurrent(_loadCurrent);
    _selectedConduit = PecEngine.recommendConduit(
      wireSpec: _selectedWire,
      conductorCount: _conductorCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('⚡ PEC 2017 Compliance Engine'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: BanaagTheme.primaryAmber,
          labelColor: BanaagTheme.primaryAmber,
          unselectedLabelColor: BanaagTheme.textMuted,
          tabs: const [
            Tab(text: 'Sizing & Fill'),
            Tab(text: 'Phase Balancer'),
            Tab(text: 'Color Coding 🎨'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSizingTab(),
          _buildPhaseBalancerTab(),
          _buildColorCodingTab(),
        ],
      ),
    );
  }

  Widget _buildSizingTab() {
    final double fillRatio = PecEngine.computeConduitFillRatio(
      wireSpec: _selectedWire,
      conductorCount: _conductorCount,
      conduitSpec: _selectedConduit,
    );

    final double vDropPercent = PecEngine.computeVoltageDropPercent(
      loadCurrentAmps: _loadCurrent,
      oneWayLengthMeters: _runLengthMeters,
      wireSpec: _selectedWire,
    );

    final int breakerRating = PecEngine.selectBreaker(_loadCurrent, _selectedWire.ampacity75C);
    final bool isOverfilled = fillRatio > 40.0;
    final bool isVoltageDropHigh = vDropPercent > 3.0;

    // Real-Time PEC Spec Validation
    final validation = PecEngine.validateCircuitSpecs(
      loadCurrentAmps: _loadCurrent,
      wireSizeMm2: _selectedWire.sizeMm2,
      breakerRatingAmps: breakerRating,
      isLighting: false,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PEC Spec Guardian Real-Time Alert Banner
          _buildSpecGuardianBanner(validation),
          const SizedBox(height: 12),

          // Telemetry Result Card
          Card(
            color: const Color(0xFF1B2028),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _metricBadge('Recommended Wire', '${_selectedWire.sizeMm2} mm²', _selectedWire.awgEquivalent),
                      _metricBadge('Breaker Trip', '$breakerRating A', 'Trip Rating'),
                    ],
                  ),
                  const Divider(color: BanaagTheme.surfaceCardBorder, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _metricBadge(
                        'Conduit Fill Ratio',
                        '${fillRatio.toStringAsFixed(1)}%',
                        isOverfilled ? '⚠️ EXCEEDS 40% LIMIT' : '✓ PEC Compliant (<40%)',
                        color: isOverfilled ? BanaagTheme.alertRed : BanaagTheme.successGreen,
                      ),
                      _metricBadge(
                        'Voltage Drop (230V)',
                        '${vDropPercent.toStringAsFixed(2)}%',
                        isVoltageDropHigh ? '⚠️ EXCEEDS 3% LIMIT' : '✓ Good (<3% Drop)',
                        color: isVoltageDropHigh ? BanaagTheme.alertRed : BanaagTheme.successGreen,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Load Current Slider
          Text('Connected Continuous Load: ${_loadCurrent.toStringAsFixed(1)} Amperes',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Slider(
            value: _loadCurrent,
            min: 1.0,
            max: 100.0,
            activeColor: BanaagTheme.primaryAmber,
            onChanged: (val) {
              setState(() {
                _loadCurrent = val;
                _recalculate();
              });
            },
          ),
          const SizedBox(height: 10),

          // Conductor Count
          Text('Number of Conductors inside Raceway: $_conductorCount Wires',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Slider(
            value: _conductorCount.toDouble(),
            min: 2,
            max: 8,
            divisions: 6,
            activeColor: BanaagTheme.primaryAmber,
            onChanged: (val) {
              setState(() {
                _conductorCount = val.toInt();
                _recalculate();
              });
            },
          ),
          const SizedBox(height: 10),

          // Run Length Slider
          Text('One-Way Circuit Run Length: ${_runLengthMeters.toStringAsFixed(0)} meters',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Slider(
            value: _runLengthMeters,
            min: 5.0,
            max: 150.0,
            activeColor: BanaagTheme.primaryAmber,
            onChanged: (val) {
              setState(() {
                _runLengthMeters = val;
              });
            },
          ),
          const SizedBox(height: 16),

          // Wire Selector (Allows testing Under-Specs & Over-Specs manually)
          const Text('Subukan ang ibang Conductor Size (Manual Testing):',
              style: TextStyle(color: BanaagTheme.primaryAmber, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: BanaagTheme.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BanaagTheme.surfaceCardBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<PecWireSpec>(
                value: _selectedWire,
                isExpanded: true,
                dropdownColor: BanaagTheme.surfaceCard,
                items: PecEngine.wireSpecs.map((w) {
                  return DropdownMenuItem<PecWireSpec>(
                    value: w,
                    child: Text('${w.sizeMm2} mm² (${w.awgEquivalent}) - Ampacity: ${w.ampacity75C.toStringAsFixed(0)} A'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedWire = val;
                      _selectedConduit = PecEngine.recommendConduit(
                        wireSpec: _selectedWire,
                        conductorCount: _conductorCount,
                      );
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Selected Specs
          ListTile(
            tileColor: BanaagTheme.surfaceCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: const Icon(Icons.cable, color: BanaagTheme.primaryAmber),
            title: Text('${_selectedWire.sizeMm2} mm² THHN / THWN-2 (${_selectedWire.awgEquivalent})'),
            subtitle: Text('Allowable Ampacity at 30°C Ambient: ${_selectedWire.ampacity75C} A'),
          ),
          const SizedBox(height: 8),
          ListTile(
            tileColor: BanaagTheme.surfaceCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: const Icon(Icons.circle_outlined, color: BanaagTheme.primaryAmber),
            title: Text('Recommended Conduit: ${_selectedConduit.tradeSize}'),
            subtitle: Text('Internal Area: ${_selectedConduit.internalAreaMm2} mm²'),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecGuardianBanner(PecValidationResult val) {
    Color cardColor;
    Color borderColor;
    Color iconColor;
    IconData icon;
    String badgeText;

    switch (val.status) {
      case PecComplianceStatus.underSpecs:
        cardColor = Colors.red.withValues(alpha: 0.15);
        borderColor = BanaagTheme.alertRed;
        iconColor = BanaagTheme.alertRed;
        icon = Icons.dangerous_outlined;
        badgeText = 'UNDER-SPECS ❌';
        break;
      case PecComplianceStatus.overSpecs:
        cardColor = Colors.orange.withValues(alpha: 0.15);
        borderColor = BanaagTheme.warningOrange;
        iconColor = BanaagTheme.warningOrange;
        icon = Icons.warning_amber_rounded;
        badgeText = 'OVER-SPECS ⚠️';
        break;
      case PecComplianceStatus.compliant:
        cardColor = Colors.green.withValues(alpha: 0.15);
        borderColor = BanaagTheme.successGreen;
        iconColor = BanaagTheme.successGreen;
        icon = Icons.verified_user_outlined;
        badgeText = 'PEC COMPLIANT ✅';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: borderColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(badgeText, style: TextStyle(color: borderColor, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  val.headline,
                  style: TextStyle(color: iconColor, fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(val.details, style: const TextStyle(fontSize: 11, color: Colors.white, height: 1.3)),
          if (val.status != PecComplianceStatus.compliant) ...[
            const SizedBox(height: 6),
            Text(
              'Rekomendasyon: Gumamit ng ${val.recommendedWireSizeMm2} mm² wire na may ${val.recommendedBreakerAmps}A breaker.',
              style: const TextStyle(fontSize: 11, color: BanaagTheme.primaryAmber, fontWeight: FontWeight.w600),
            ),
          ],
          if (val.pecCitations.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.menu_book, size: 12, color: BanaagTheme.primaryAmber),
                      SizedBox(width: 4),
                      Text(
                        'Batayan sa PEC 2017 Book:',
                        style: TextStyle(fontSize: 10, color: BanaagTheme.primaryAmber, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ...val.pecCitations.map(
                    (citation) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        '• $citation',
                        style: const TextStyle(fontSize: 10, color: BanaagTheme.textMuted, height: 1.25),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }



  Widget _metricBadge(String label, String value, String sub, {Color color = BanaagTheme.primaryAmber}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: BanaagTheme.textMuted, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(sub, style: TextStyle(color: color.withValues(alpha: 0.85), fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildPhaseBalancerTab() {
    final balanced = PecEngine.balanceSinglePhaseLines(_circuits);
    final List<Map<String, dynamic>> phaseA = balanced['PhaseA']!;
    final List<Map<String, dynamic>> phaseB = balanced['PhaseB']!;

    double totalVaA = phaseA.fold(0.0, (sum, item) => sum + (item['loadVA'] as double));
    double totalVaB = phaseB.fold(0.0, (sum, item) => sum + (item['loadVA'] as double));

    double currentA = totalVaA / 230.0;
    double currentB = totalVaB / 230.0;
    double unbalancePercent = ((currentA - currentB).abs() / ((currentA + currentB) / 2)) * 100.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: const Color(0xFF1B2028),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _metricBadge('Phase A Total Load', '${totalVaA.toStringAsFixed(0)} VA', '${currentA.toStringAsFixed(1)} Amps'),
                      _metricBadge('Phase B Total Load', '${totalVaB.toStringAsFixed(0)} VA', '${currentB.toStringAsFixed(1)} Amps'),
                    ],
                  ),
                  const Divider(color: BanaagTheme.surfaceCardBorder, height: 24),
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: BanaagTheme.successGreen),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Unbalance: ${unbalancePercent.toStringAsFixed(1)}% (Excellent balance, protects neutral from overheating)',
                          style: const TextStyle(color: BanaagTheme.successGreen, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Auto-Balanced Panel Schedule Distribution', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                      decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                      child: const Text('PHASE A (Line 1)', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 8),
                    ...phaseA.map((c) => _circuitTile(c)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                      decoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                      child: const Text('PHASE B (Line 2)', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 8),
                    ...phaseB.map((c) => _circuitTile(c)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circuitTile(Map<String, dynamic> circuit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: BanaagTheme.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: BanaagTheme.surfaceCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(circuit['name'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('${circuit['loadVA']} VA  (${(circuit['loadVA'] / 230.0).toStringAsFixed(1)}A)',
              style: const TextStyle(color: BanaagTheme.primaryAmber, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildColorCodingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Notice
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BanaagTheme.primaryAmber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: BanaagTheme.primaryAmber.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.palette_outlined, color: BanaagTheme.primaryAmber, size: 24),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Philippine Electrical Code (PEC 2017) Color Standards',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                      ),
                      Text(
                        'Article 2.0.1.6 & Article 2.50.6.10: Tamang identification ng Live, Grounded (Neutral), at Grounding conductors.',
                        style: TextStyle(fontSize: 11, color: BanaagTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Standard Color Swatch Legend
          const Text('Standard Conductor Identification:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          ...ConductorFunction.values.map((cond) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BanaagTheme.surfaceCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: BanaagTheme.surfaceCardBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Color(cond.colorHex),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white30, width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(cond.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Color(cond.colorHex).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                cond.colorName,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(cond.description, style: const TextStyle(fontSize: 11, color: BanaagTheme.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),

          // Circuit Wiring Rules List
          const Text('PEC Installation Scenarios & Application:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          ...WiringColorCodingEngine.standardRules.map((rule) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2430),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: BanaagTheme.surfaceCardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rule.circuitType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: BanaagTheme.primaryAmber)),
                  const SizedBox(height: 4),
                  Text('System: ${rule.systemVoltage}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: rule.conductors.map((c) {
                      return Chip(
                        avatar: CircleAvatar(
                          backgroundColor: Color(c.colorHex),
                          radius: 6,
                        ),
                        label: Text('${c.colorName} (${c.label.split(" ").first})', style: const TextStyle(fontSize: 10)),
                        backgroundColor: BanaagTheme.surfaceCard,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Text(rule.explanation, style: const TextStyle(fontSize: 11, color: BanaagTheme.textMuted)),
                  const SizedBox(height: 6),
                  Text('📖 ${rule.pecCitation}', style: const TextStyle(fontSize: 10, color: BanaagTheme.successGreen, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
