import 'package:flutter/material.dart';
import '../theme/banaag_theme.dart';

class DrawingGuidelinesModal extends StatefulWidget {
  final VoidCallback? onLoadSamplePlan;

  const DrawingGuidelinesModal({super.key, this.onLoadSamplePlan});

  static Future<void> show(BuildContext context, {VoidCallback? onLoadSamplePlan}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DrawingGuidelinesModal(onLoadSamplePlan: onLoadSamplePlan),
    );
  }

  @override
  State<DrawingGuidelinesModal> createState() => _DrawingGuidelinesModalState();
}

class _DrawingGuidelinesModalState extends State<DrawingGuidelinesModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF0C0A09),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Color(0xFF2C221C), width: 1.5),
          left: BorderSide(color: Color(0xFF2C221C), width: 1),
          right: BorderSide(color: Color(0xFF2C221C), width: 1),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: BanaagTheme.primaryAmber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: BanaagTheme.primaryAmber.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: BanaagTheme.primaryAmber, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Floor Plan Drawing Guidelines',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                      ),
                      Text(
                        'Mga Gabay para sa 100% Tamang Pagbasa ng AI',
                        style: TextStyle(fontSize: 11, color: BanaagTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Tab Bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF181412),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF2C221C)),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: BanaagTheme.primaryAmber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: BanaagTheme.primaryAmber.withValues(alpha: 0.6)),
              ),
              labelColor: BanaagTheme.primaryAmber,
              unselectedLabelColor: BanaagTheme.textMuted,
              labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(icon: Icon(Icons.edit_note_rounded, size: 18), text: '1. Papel & Pen'),
                Tab(icon: Icon(Icons.straighten_rounded, size: 18), text: '2. Sukat & Linya'),
                Tab(icon: Icon(Icons.photo_size_select_actual_outlined, size: 18), text: '3. Sample Plan'),
              ],
            ),
          ),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTab1PaperAndPen(),
                _buildTab2DimensionsAndLines(),
                _buildTab3SampleAndDemo(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: PAPEL AT PANULAT ---
  Widget _buildTab1PaperAndPen() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionCard(
          title: 'Tamang Papel at Panulat (DOs)',
          icon: Icons.check_circle_rounded,
          iconColor: BanaagTheme.successGreen,
          children: [
            _buildBulletItem(
              'Plain White Paper ang Pinakamaganda',
              'Mas mainam gamitin ang plain bond paper, sketching pad, o likod ng malinis na papel. Walang distractions para sa AI scanner.',
              isGood: true,
            ),
            _buildBulletItem(
              'Madilim at Makapal na Ballpen',
              'Gumamit ng dark black o dark blue gel pen, sign pen (0.5mm to 1.0mm), o fine marker. Iwasan ang malabong lapis.',
              isGood: true,
            ),
            _buildBulletItem(
              'Isahang Tuwid na Guhit (Single Stroke)',
              'Gumuhit gamit ang isang buong solid line bawat pader. Mas mainam gumamit ng ruler o ID card para tuwid ang 90° corners.',
              isGood: true,
            ),
            _buildBulletItem(
              'Pantay na Liwanag sa Pagkuha ng Photo',
              'Kuhanan ang papel mula sa itaas (top-down view). Siguraduhing walang anino ng phone o kamay sa ibabaw ng drawing.',
              isGood: true,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          title: 'Kung Notebook na may Blue Lines ang Gamit',
          icon: Icons.info_outline_rounded,
          iconColor: Colors.cyanAccent,
          children: [
            _buildBulletItem(
              'May Built-in Blue Filter ang BANAAG',
              'Kaya ng ating AI na salain at dedmahin ang mga asul na guhit ng notebook, BASTA maitim at mas makapal ang pen na ginamit mo sa pader.',
              isGood: true,
            ),
            _buildBulletItem(
              'Huwag Ipatong ang Pader sa Asul na Guhit',
              'Hangga\'t maaari, huwag itapat ang interior wall nang eksakto sa mismong blue line ng papel upang hindi magka-confusion ang detector.',
              isGood: true,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          title: 'Mga Dapat Iwasan (DON\'Ts)',
          icon: Icons.cancel_rounded,
          iconColor: BanaagTheme.alertRed,
          children: [
            _buildBulletItem(
              'Malabong Lapis o Kumukupas na Tinta',
              'Hindi mababasa ng scanner ang manipis o kupas na guhit ng lapis.',
              isGood: false,
            ),
            _buildBulletItem(
              'Paulit-ulit na Mabuhok na Guhit (Hairy/Sketchy Lines)',
              'Iwasan ang parang architectural sketch na pabalik-balik ang guhit sa iisang pader. Gawing isang solidong linya lang.',
              isGood: false,
            ),
            _buildBulletItem(
              'Lukot-lukot o May Malalakas na Anino',
              'Ang tupi at anino sa papel ay maaaring mapagkamalang partition wall ng computer vision.',
              isGood: false,
            ),
          ],
        ),
      ],
    );
  }

  // --- TAB 2: SUKAT AT LABELS ---
  Widget _buildTab2DimensionsAndLines() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionCard(
          title: 'Tamang Pagsulat ng Sukat (Dimensioning)',
          icon: Icons.straighten_rounded,
          iconColor: BanaagTheme.primaryAmber,
          children: [
            _buildBulletItem(
              'Isulat ang Sukat sa LABAS ng Floor Plan',
              'Ilagay ang kabuuang sukat sa itaas (Top Width) at sa kanan (Right Length) sa labas ng kahon ng bahay.',
              isGood: true,
            ),
            _buildBulletItem(
              'Lagyan ng "m" Unit (Hal. "5m", "4.0m", "2.5m")',
              'Awtomatikong hinahanap ng OCR scanner ang numero na may "m" para i-prefill agad ang pader nang hindi mo na kailangang i-type.',
              isGood: true,
            ),
            _buildBulletItem(
              'Gamitin ang Extension Marks: |--- 5m ---|',
              'Ang dalawang dulo ng sukat na may patayong tick mark ay tumutulong sa AI na tukuyin kung saang pader nakatapat ang numero.',
              isGood: true,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          title: 'Pader at Koneksyon ng mga Kwarto',
          icon: Icons.meeting_room_rounded,
          iconColor: Colors.cyanAccent,
          children: [
            _buildBulletItem(
              'Isara ang Sulok (Closed 90° Corners)',
              'Siguraduhing magkadikit ang dulo ng bawat pader. Ang may butas na sulok ay maaaring magdulot na hindi makilala ang kwarto.',
              isGood: true,
            ),
            _buildBulletItem(
              'Idugtong ang Interior Walls sa Perimeter',
              'Dapat nakadikit ang dividing wall sa magkabilang gilid o sa isa pang pader para ma-compute ang flood-fill ng bawat space.',
              isGood: true,
            ),
            _buildBulletItem(
              'Pangalan ng Kwarto sa Bakanteng Gitna',
              'Isulat ang "BED", "LIVING", o "KITCHEN" sa gitna ng kwarto, malayo sa mga pader para hindi mapagkamalang sukat.',
              isGood: true,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          title: 'Maling Pagsulat ng Sukat (DON\'Ts)',
          icon: Icons.warning_amber_rounded,
          iconColor: BanaagTheme.warningOrange,
          children: [
            _buildBulletItem(
              'Huwag Isulat ang Sukat sa Ibabaw ng Pader',
              'Kapag tumagos ang numero sa mismong linya ng pader, maaaring maputol ang pader sa tingin ng image recognition.',
              isGood: false,
            ),
            _buildBulletItem(
              'Huwag Maglagay ng Sobrang Daming Guhit sa Loob',
              'Iwasan muna ang pag-drawing ng mga kama, lababo, o pinto sa loob habang nagka-calibrate ng pader.',
              isGood: false,
            ),
          ],
        ),
      ],
    );
  }

  // --- TAB 3: SAMPLE PLAN AT DEMO ---
  Widget _buildTab3SampleAndDemo() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Visual Diagram of the Ideal Plan
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF181412),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: BanaagTheme.primaryAmber.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.verified_rounded, color: BanaagTheme.successGreen, size: 18),
                  SizedBox(width: 8),
                  Text('Ehemplo ng Perpektong Drawing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                ],
              ),
              const SizedBox(height: 10),
              // Simulated blueprint visual
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1218),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
                ),
                child: CustomPaint(
                  painter: _SampleFloorPlanPainter(),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Bakit epektibo ito para sa BANAAG AI:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: BanaagTheme.primaryAmber),
              ),
              const SizedBox(height: 4),
              _buildMicroTip('✅ Ang "5.0m" at "4.0m" ay nasa labas ng drawing na may malinaw na extension lines.'),
              _buildMicroTip('✅ 100% sarado ang 90° corners, walang open gaps.'),
              _buildMicroTip('✅ Malinis ang loob ng mga kwarto kaya perpektong na-flood-fill ng AI ang 2 rooms.'),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Action card: Load Sample Demo Plan
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: BanaagTheme.primaryAmber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: BanaagTheme.primaryAmber.withValues(alpha: 0.6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.bolt_rounded, color: BanaagTheme.primaryAmber, size: 22),
                  SizedBox(width: 8),
                  Text('Gusto mo bang subukan agad?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Puwede mong i-load agad ang sample drawing na ito sa Calibration Screen para maranasan kung paano mag-auto-detect at mag-scale ang app nang hindi na kailangang mag-drawing ngayon.',
                style: TextStyle(fontSize: 11, color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: BanaagTheme.primaryAmber,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: const Text('⚡ Subukan ang Sample Plan na Ito', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () {
                  Navigator.pop(context);
                  widget.onLoadSamplePlan?.call();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF181412),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2C221C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _buildBulletItem(String title, String desc, {required bool isGood}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isGood ? '•' : '✕',
            style: TextStyle(
              color: isGood ? BanaagTheme.successGreen : BanaagTheme.alertRed,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 11, color: Colors.white70, height: 1.35),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  TextSpan(text: desc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicroTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10.5, color: Colors.white70),
      ),
    );
  }
}

/// Custom painter to draw a crisp architectural sample sketch on the blueprint canvas
class _SampleFloorPlanPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF0F131A);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Draw subtle grid
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 0.8;
    for (double x = 0; x < size.width; x += 15) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 15) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Outer plan bounds
    final padX = size.width * 0.18;
    final padY = size.height * 0.22;
    final planW = size.width * 0.64;
    final planH = size.height * 0.60;
    final splitX = padX + planW * 0.55;

    // Room colors (semi-transparent fill)
    final room1Fill = Paint()..color = Colors.cyanAccent.withValues(alpha: 0.12);
    final room2Fill = Paint()..color = BanaagTheme.primaryAmber.withValues(alpha: 0.12);
    canvas.drawRect(Rect.fromLTWH(padX, padY, splitX - padX, planH), room1Fill);
    canvas.drawRect(Rect.fromLTWH(splitX, padY, padX + planW - splitX, planH), room2Fill);

    // Walls (crisp white line)
    final wallPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    // Outer box
    canvas.drawRect(Rect.fromLTWH(padX, padY, planW, planH), wallPaint);

    // Interior dividing wall
    canvas.drawLine(Offset(splitX, padY), Offset(splitX, padY + planH), wallPaint);

    // Dimension lines (Cyan)
    final dimPaint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 1.0;

    // Top Dimension Line: |----- 5.0m -----|
    final topDimY = padY - 14;
    canvas.drawLine(Offset(padX, topDimY), Offset(padX + planW, topDimY), dimPaint);
    canvas.drawLine(Offset(padX, topDimY - 4), Offset(padX, topDimY + 4), dimPaint);
    canvas.drawLine(Offset(padX + planW, topDimY - 4), Offset(padX + planW, topDimY + 4), dimPaint);

    // Right Dimension Line: |----- 4.0m -----|
    final rightDimX = padX + planW + 14;
    canvas.drawLine(Offset(rightDimX, padY), Offset(rightDimX, padY + planH), dimPaint);
    canvas.drawLine(Offset(rightDimX - 4, padY), Offset(rightDimX + 4, padY), dimPaint);
    canvas.drawLine(Offset(rightDimX - 4, padY + planH), Offset(rightDimX + 4, padY + planH), dimPaint);

    // Text helper
    void drawLabel(String text, Offset center, Color color, {double fontSize = 10, bool bold = true}) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
    }

    drawLabel('5.0m', Offset(padX + planW / 2, topDimY - 10), Colors.cyanAccent, fontSize: 11);
    drawLabel('4.0m', Offset(rightDimX + 16, padY + planH / 2), Colors.cyanAccent, fontSize: 11);
    drawLabel('ROOM 1', Offset((padX + splitX) / 2, padY + planH / 2 - 8), Colors.white70, fontSize: 10);
    drawLabel('3.0m x 4.0m', Offset((padX + splitX) / 2, padY + planH / 2 + 8), Colors.white38, fontSize: 8.5);
    drawLabel('ROOM 2', Offset((splitX + padX + planW) / 2, padY + planH / 2 - 8), Colors.white70, fontSize: 10);
    drawLabel('2.0m x 4.0m', Offset((splitX + padX + planW) / 2, padY + planH / 2 + 8), Colors.white38, fontSize: 8.5);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
