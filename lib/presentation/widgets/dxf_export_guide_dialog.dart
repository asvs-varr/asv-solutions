import 'package:flutter/material.dart';
import '../theme/banaag_theme.dart';

class DxfExportGuideDialog {
  /// Opens the modal guide for 100% Guaranteed AutoCAD DXF Parsing
  static void show(BuildContext context, {VoidCallback? onUploadPressed}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BanaagTheme.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: BanaagTheme.primaryAmber, width: 1.5),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: BanaagTheme.primaryAmber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.architecture, color: BanaagTheme.primaryAmber, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AutoCAD .DXF Export Guide',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    '100% Guaranteed Reader Protocol',
                    style: TextStyle(fontSize: 11, color: BanaagTheme.primaryAmber, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E232D),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: BanaagTheme.primaryAmber, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sundan ang 4 na hakbang na ito sa AutoCAD bago i-import para awtomatikong mabasa ang mga pader, devices, at kwarto.',
                          style: TextStyle(fontSize: 11, color: BanaagTheme.textHighEmphasis, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildStepItem(
                  stepNumber: '1',
                  badge: 'CLEAN ENTITIES',
                  title: 'Explode Blocks & Purge Drawing',
                  desc: 'Huwag mag-export ng nested dynamic blocks o third-party AEC objects na hindi nababasa ng raw parsers.',
                  commands: ['EXPLODE (select all electrical symbols & walls)', 'PURGE (purge all unused layers & blocks)', 'AUDIT (fix drawing errors automatically)'],
                ),
                const SizedBox(height: 14),
                _buildStepItem(
                  stepNumber: '2',
                  badge: 'LAYER ISOLATION',
                  title: 'Standard Layer Naming',
                  desc: 'Ilagay sa tamang standard layers ang bawat elemento para ma-filter nang 100% ng Banaag Engine:',
                  layers: [
                    {'layer': 'A-WALL / E-WALL', 'desc': 'Exterior at Interior partitions (Lines & Polylines)'},
                    {'layer': 'E-LITE', 'desc': 'Luminaires, downlights, switches'},
                    {'layer': 'E-POWR', 'desc': 'Convenience outlets, ACU, panels'},
                    {'layer': 'A-ROOM / E-TXT', 'desc': 'Text labels ng kwarto (e.g. Living, Kitchen, BR)'},
                  ],
                ),
                const SizedBox(height: 14),
                _buildStepItem(
                  stepNumber: '3',
                  badge: 'FORMAT TYPE',
                  title: 'Save as ASCII AutoCAD 2018 DXF',
                  desc: 'Pumunta sa File > Save As o i-type ang DXFOUT. Piliin ang format:',
                  codeSnippet: 'AutoCAD 2018 DXF (*.dxf)  [ASCII Mode]',
                  warningNote: 'Iwasan ang Binary DXF o lumang proprietary DWG format.',
                ),
                const SizedBox(height: 14),
                _buildStepItem(
                  stepNumber: '4',
                  badge: 'SCALE & ORIGIN',
                  title: '1:1 Scale & Insertion Units',
                  desc: 'Tiyaking naka-scale sa totoong sukat sa Model Space:',
                  bullets: [
                    'Drawing Units: Millimeters (mm) o Meters (m).',
                    'Origin: I-move ang floor plan malapit sa (0,0,0) coordinate.',
                    'Drawing Area: I-export mula sa Model Space, hindi sa Paper Space Layout.',
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (onUploadPressed != null) ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: BanaagTheme.primaryAmber,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.cloud_upload_outlined, size: 18),
              label: const Text('I-upload ang .DXF Ngayon', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.pop(ctx);
                onUploadPressed();
              },
            ),
            const SizedBox(height: 6),
          ],
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: onUploadPressed != null ? Colors.transparent : BanaagTheme.primaryAmber,
              foregroundColor: onUploadPressed != null ? BanaagTheme.textMuted : Colors.black,
              elevation: onUploadPressed != null ? 0 : 2,
              minimumSize: const Size(double.infinity, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text(onUploadPressed != null ? 'I-close ang Guide' : 'Naintindihan, I-close ang Guide', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static Widget _buildStepItem({
    required String stepNumber,
    required String badge,
    required String title,
    required String desc,
    List<String>? commands,
    List<Map<String, String>>? layers,
    String? codeSnippet,
    String? warningNote,
    List<String>? bullets,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141820),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: BanaagTheme.primaryAmber,
                child: Text(
                  stepNumber,
                  style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: BanaagTheme.primaryAmber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(color: BanaagTheme.primaryAmber, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(fontSize: 11, color: BanaagTheme.textMuted, height: 1.3)),
          if (commands != null) ...[
            const SizedBox(height: 8),
            ...commands.map((cmd) => Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Row(
                    children: [
                      const Icon(Icons.terminal, color: BanaagTheme.primaryAmber, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          cmd,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF81C784)),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
          if (layers != null) ...[
            const SizedBox(height: 8),
            ...layers.map((l) => Container(
                  margin: const EdgeInsets.only(bottom: 4.0),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Text(l['layer']!, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 11, color: BanaagTheme.primaryAmber)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(l['desc']!, style: const TextStyle(fontSize: 10, color: BanaagTheme.textMuted))),
                    ],
                  ),
                )),
          ],
          if (codeSnippet != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: BanaagTheme.primaryAmber.withValues(alpha: 0.3)),
              ),
              child: Text(codeSnippet, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: BanaagTheme.primaryAmber, fontWeight: FontWeight.bold)),
            ),
          ],
          if (warningNote != null) ...[
            const SizedBox(height: 6),
            Text('⚠️ $warningNote', style: const TextStyle(fontSize: 10, color: Colors.orangeAccent, fontStyle: FontStyle.italic)),
          ],
          if (bullets != null) ...[
            const SizedBox(height: 6),
            ...bullets.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 2.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(color: BanaagTheme.primaryAmber, fontSize: 12)),
                      Expanded(child: Text(b, style: const TextStyle(fontSize: 11, color: BanaagTheme.textHighEmphasis))),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}
