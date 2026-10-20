import 'package:flutter/material.dart';
import '../../domain/models.dart';
import '../../data/project_repository.dart';
import '../theme/banaag_theme.dart';

class UtilityServiceDropDialog extends StatefulWidget {
  final Project project;
  final PhaseCheckItem checkItem;
  final VoidCallback onSaved;

  const UtilityServiceDropDialog({
    super.key,
    required this.project,
    required this.checkItem,
    required this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    required Project project,
    required PhaseCheckItem checkItem,
    required VoidCallback onSaved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => UtilityServiceDropDialog(
        project: project,
        checkItem: checkItem,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<UtilityServiceDropDialog> createState() => _UtilityServiceDropDialogState();
}

class _UtilityServiceDropDialogState extends State<UtilityServiceDropDialog> {
  late TextEditingController _poleTagController;
  late TextEditingController _distanceController;
  late TextEditingController _notesController;
  late bool _crossesRoadway;
  late String _serviceEntranceType;
  late String _utilityProvider;

  @override
  void initState() {
    super.initState();
    final existing = widget.project.utilityServiceDrop;
    _poleTagController = TextEditingController(text: existing?.poleNumberTag ?? 'SIN-4821');
    _distanceController = TextEditingController(text: (existing?.distanceToPoleMeters ?? 18.0).toStringAsFixed(1));
    _notesController = TextEditingController(text: existing?.notes ?? '');
    _crossesRoadway = existing?.crossesRoadway ?? false;
    _serviceEntranceType = existing?.serviceEntranceType ?? 'Overhead Masthead / Weatherhead';
    _utilityProvider = existing?.utilityProvider ?? widget.project.utilityProvider;
  }

  @override
  void dispose() {
    _poleTagController.dispose();
    _distanceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _currentDistance => double.tryParse(_distanceController.text) ?? 15.0;

  @override
  Widget build(BuildContext context) {
    final distance = _currentDistance;
    final assessment = UtilityServiceDropAssessment(
      poleNumberTag: _poleTagController.text.trim(),
      distanceToPoleMeters: distance,
      crossesRoadway: _crossesRoadway,
      serviceEntranceType: _serviceEntranceType,
      utilityProvider: _utilityProvider,
      notes: _notesController.text.trim(),
    );

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF161922),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: BanaagTheme.primaryAmber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bolt, color: BanaagTheme.primaryAmber, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Utility Service Drop & Pole Coordinates',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                      ),
                      Text(
                        'PEC Art 2.30 & Distribution Utility (DU) Clearance Engineering',
                        style: const TextStyle(fontSize: 11, color: BanaagTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Form inputs
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _poleTagController,
                    decoration: InputDecoration(
                      labelText: 'Pole Tag / SIN #',
                      labelStyle: const TextStyle(fontSize: 12, color: BanaagTheme.primaryAmber),
                      hintText: 'e.g. SIN-10492 or M-4821',
                      filled: true,
                      fillColor: BanaagTheme.surfaceCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.tag, size: 18, color: BanaagTheme.primaryAmber),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _distanceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Distansya (Metro)',
                      labelStyle: const TextStyle(fontSize: 12, color: BanaagTheme.primaryAmber),
                      hintText: '18.0',
                      filled: true,
                      fillColor: BanaagTheme.surfaceCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      suffixText: 'm',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Distribution Utility & Service Entrance Type
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: BanaagTheme.surfaceCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: BanaagTheme.surfaceCardBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _utilityProvider,
                        dropdownColor: BanaagTheme.surfaceCard,
                        isExpanded: true,
                        items: ['Meralco', 'CANORECO', 'CASURECO', 'FLECO', 'PELCO', 'VECO', 'Davao Light']
                            .map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _utilityProvider = val);
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: BanaagTheme.surfaceCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: BanaagTheme.surfaceCardBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _serviceEntranceType,
                        dropdownColor: BanaagTheme.surfaceCard,
                        isExpanded: true,
                        items: [
                          'Overhead Masthead / Weatherhead',
                          'Underground Service Lateral',
                        ]
                            .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _serviceEntranceType = val);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Roadway Crossing Switch
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Crosses Public Street / Roadway?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text(
                _crossesRoadway
                    ? 'PEC Art 2.30.2.4: Minimum 5.5m (18ft) vertical road clearance required over vehicular traffic.'
                    : 'PEC Art 2.30.2.4: Minimum 4.5m (15ft) vertical clearance for residential driveways and footpaths.',
                style: const TextStyle(fontSize: 11, color: BanaagTheme.textMuted),
              ),
              value: _crossesRoadway,
              activeThumbColor: BanaagTheme.primaryAmber,
              onChanged: (val) => setState(() => _crossesRoadway = val),
            ),
            const SizedBox(height: 8),

            // Live Engineering Warning & Wire BOM Calculation Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: assessment.requiresIntermediatePole
                    ? const Color(0xFF2A1515)
                    : const Color(0xFF14241B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: assessment.requiresIntermediatePole
                      ? BanaagTheme.alertRed
                      : BanaagTheme.successGreen.withValues(alpha: 0.6),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        assessment.requiresIntermediatePole ? Icons.warning_amber_rounded : Icons.verified,
                        color: assessment.requiresIntermediatePole ? BanaagTheme.alertRed : BanaagTheme.successGreen,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          assessment.requiresIntermediatePole ? 'INTERMEDIATE POLE REQUIRED' : 'PASOK SA SERVICE SPAN LIMIT',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: assessment.requiresIntermediatePole ? BanaagTheme.alertRed : BanaagTheme.successGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    assessment.pecComplianceNote,
                    style: const TextStyle(fontSize: 11, color: Colors.white70, height: 1.3),
                  ),
                  const Divider(color: Colors.white12, height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Drop Cable Bill of Materials', style: TextStyle(fontSize: 10, color: BanaagTheme.textMuted)),
                          Text(
                            '${assessment.estimatedDuplexWireMeters.toStringAsFixed(1)}m Duplex #6 AWG Al',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: BanaagTheme.primaryAmber),
                          ),
                          const Text('Kasama ang +3m drip loop & service cap', style: TextStyle(fontSize: 9, color: Colors.white54)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Target Height / Clearance', style: TextStyle(fontSize: 10, color: BanaagTheme.textMuted)),
                          Text(
                            '${assessment.requiredVerticalClearanceMeters} meters',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                          ),
                          Text(_crossesRoadway ? 'Public Street' : 'Driveway/Yard', style: const TextStyle(fontSize: 9, color: Colors.white54)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Notes
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Field Notes & Landmarking',
                hintText: 'e.g., Transformer pole directly opposite Lot 12; overhead secondary rack intact.',
                hintStyle: const TextStyle(fontSize: 11, color: BanaagTheme.textMuted),
                filled: true,
                fillColor: BanaagTheme.surfaceCard,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 18),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: BanaagTheme.primaryAmber,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Save Service Drop Assessment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () {
                  final finalAssessment = UtilityServiceDropAssessment(
                    poleNumberTag: _poleTagController.text.trim().isEmpty ? 'SIN-4821' : _poleTagController.text.trim(),
                    distanceToPoleMeters: _currentDistance,
                    crossesRoadway: _crossesRoadway,
                    serviceEntranceType: _serviceEntranceType,
                    utilityProvider: _utilityProvider,
                    notes: _notesController.text.trim(),
                  );

                  widget.project.utilityServiceDrop = finalAssessment;
                  widget.checkItem.isCompleted = true;
                  widget.checkItem.notes =
                      'Pole: ${finalAssessment.poleNumberTag} • ${finalAssessment.distanceToPoleMeters}m (${finalAssessment.crossesRoadway ? 'Tawid-Kalsada' : 'Driveway'})';

                  // Check if Phase 1 completed
                  final p1 = widget.project.phases.firstWhere(
                    (p) => p.type == ProjectPhaseType.consultation,
                    orElse: () => widget.project.phases[0],
                  );
                  if (p1.checklist.every((c) => c.isCompleted)) {
                    p1.isCompleted = true;
                  }

                  ProjectRepository.instance.updateProject(widget.project);
                  widget.onSaved();
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
