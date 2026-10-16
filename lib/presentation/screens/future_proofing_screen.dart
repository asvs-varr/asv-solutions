// BANAAG Future-Proofing Hub Screen: Solar Net-Metering, EV Chargers, and Smart Home Ready Systems

import 'package:flutter/material.dart';
import '../../domain/future_proofing_engine.dart';
import '../theme/banaag_theme.dart';

class FutureProofingScreen extends StatefulWidget {
  const FutureProofingScreen({super.key});

  @override
  State<FutureProofingScreen> createState() => _FutureProofingScreenState();
}

class _FutureProofingScreenState extends State<FutureProofingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  double _solarKw = 5.0; // 5kW standard residential solar setup
  double _evKw = 7.4; // 7.4kW / 32A standard EV home wallbox

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔮 Future-Proofing & Modern Systems'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: BanaagTheme.primaryAmber,
          labelColor: BanaagTheme.primaryAmber,
          unselectedLabelColor: BanaagTheme.textMuted,
          tabs: const [
            Tab(text: 'Solar Net-Metering'),
            Tab(text: 'EV Charger'),
            Tab(text: 'Smart Home & IoT'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSolarTab(),
          _buildEvTab(),
          _buildSmartHomeTab(),
        ],
      ),
    );
  }

  Widget _buildSolarTab() {
    final spec = FutureProofingEngine.calculateSolarReadiness(_solarKw);

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
                      _metricBadge('PV Capacity', '${spec.systemKw.toStringAsFixed(1)} kW', 'Grid-Tied System'),
                      _metricBadge('Inverter Output', '${spec.inverterAcOutputAmps.toStringAsFixed(1)} A', 'Continuous Current'),
                    ],
                  ),
                  const Divider(color: BanaagTheme.surfaceCardBorder, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _metricBadge('Solar AC Breaker', '${spec.recommendedBreaker} A (2P)', 'Backfeed Breaker', color: BanaagTheme.successGreen),
                      _metricBadge('AC Feeder Wire', '${spec.recommendedWire.sizeMm2} mm²', spec.recommendedWire.awgEquivalent, color: BanaagTheme.primaryAmber),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text('Solar PV System Size: ${_solarKw.toStringAsFixed(1)} kWp', style: const TextStyle(fontWeight: FontWeight.bold)),
          Slider(
            value: _solarKw,
            min: 1.0,
            max: 30.0,
            divisions: 29,
            activeColor: BanaagTheme.primaryAmber,
            onChanged: (val) => setState(() => _solarKw = val),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BanaagTheme.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BanaagTheme.surfaceCardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.verified, color: BanaagTheme.primaryAmber, size: 20),
                    SizedBox(width: 8),
                    Text('PEC Article 6.90 & Net-Metering Compliance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(spec.rapidShutdownRequirement, style: const TextStyle(color: BanaagTheme.textHighEmphasis, fontSize: 12)),
                const SizedBox(height: 6),
                Text(spec.utilityComplianceNote, style: const TextStyle(color: BanaagTheme.textMuted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvTab() {
    final spec = FutureProofingEngine.calculateEvCharger(_evKw);

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
                      _metricBadge('EV Charger Power', '${spec.powerKw.toStringAsFixed(1)} kW', 'Level 2 AC Home Wallbox'),
                      _metricBadge('Continuous Draw', '${spec.continuousCurrentAmps.toStringAsFixed(1)} A', '125% PEC Factor'),
                    ],
                  ),
                  const Divider(color: BanaagTheme.surfaceCardBorder, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _metricBadge('Dedicated Breaker', '${spec.recommendedBreaker} A (2P)', 'Industrial Trip', color: BanaagTheme.successGreen),
                      _metricBadge('Heavy Feeder Wire', '${spec.recommendedWire.sizeMm2} mm²', spec.recommendedWire.awgEquivalent, color: BanaagTheme.primaryAmber),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text('EV Charger Rating: ${_evKw.toStringAsFixed(1)} kW (Single Phase 230V)', style: const TextStyle(fontWeight: FontWeight.bold)),
          Slider(
            value: _evKw,
            min: 3.5,
            max: 22.0,
            divisions: 37,
            activeColor: BanaagTheme.primaryAmber,
            onChanged: (val) => setState(() => _evKw = val),
          ),
          const SizedBox(height: 12),

          ListTile(
            tileColor: BanaagTheme.surfaceCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: const Icon(Icons.ev_station, color: BanaagTheme.primaryAmber),
            title: const Text('Conduit & Grounding Specification'),
            subtitle: Text(spec.conduitRecommendation, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartHomeTab() {
    final audit = FutureProofingEngine.getSmartHomeAudit();

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: audit.length,
      itemBuilder: (context, index) {
        final item = audit[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(item['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: BanaagTheme.primaryAmber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(item['standard']!, style: const TextStyle(color: BanaagTheme.primaryAmber, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(item['desc']!, style: const TextStyle(color: BanaagTheme.textMuted, fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _metricBadge(String label, String value, String sub, {Color color = BanaagTheme.primaryAmber}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: BanaagTheme.textMuted, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(sub, style: TextStyle(color: color.withValues(alpha: 0.85), fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
