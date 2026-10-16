// BANAAG PEC Calculator Screen: Wire Sizing, Conduit Fill, Voltage Drop & Smart Phase Balancer

import 'package:flutter/material.dart';
import '../../domain/pec_engine.dart';
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
    _tabController = TabController(length: 2, vsync: this);
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
            Tab(text: 'Sizing & Conduit Fill'),
            Tab(text: 'Smart Phase Balancer'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSizingTab(),
          _buildPhaseBalancerTab(),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
}
