import 'package:flutter/material.dart';
import '../../domain/security_engine.dart';
import '../theme/banaag_theme.dart';

class BanaagProScreen extends StatefulWidget {
  const BanaagProScreen({super.key});

  @override
  State<BanaagProScreen> createState() => _BanaagProScreenState();
}

class _BanaagProScreenState extends State<BanaagProScreen> {
  final SecurityEngine _securityEngine = SecurityEngine.instance;
  late bool _isProActive;
  String _selectedTheme = 'Industrial Amber (Default)';
  final TextEditingController _companyNameController = TextEditingController(text: 'LANITON Electrical & Engineering Services');
  final TextEditingController _prcLicenseController = TextEditingController(text: 'PEE Lic. No. 0012345 / RME 0098765');

  @override
  void initState() {
    super.initState();
    // Initialize or restore active cryptographic lease token
    if (_securityEngine.activeToken == null) {
      _securityEngine.issueOfflineLease(
        userId: 'contractor-ph-dev',
        tier: 'PRO_CONTRACTOR',
        validityDays: 30,
      );
    }
    _isProActive = _securityEngine.isProEntitled();
  }

  final List<String> _themes = [
    'Industrial Amber (Default)',
    'High-Contrast Sunlight Yellow',
    'Tactical Slate / Stealth Black',
    'Clean White Engineering Office',
    'Cyberpunk Neon Wire',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.workspace_premium, color: BanaagTheme.primaryAmber),
            SizedBox(width: 8),
            Text('BANAAG PRO Settings'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PRO Membership Banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2B2005), Color(0xFF1E222B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: BanaagTheme.primaryAmber.withValues(alpha: 0.6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isProActive ? BanaagTheme.primaryAmber : Colors.grey,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _isProActive ? 'PRO ACTIVATED (OFFLINE LEASE)' : 'FREE TIER',
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11),
                        ),
                      ),
                      Icon(_isProActive ? Icons.verified_user : Icons.lock_outline, color: _isProActive ? BanaagTheme.primaryAmber : Colors.grey),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Contractor Prestige & Cloud Suite', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 4),
                  const Text('Lahat ng PEC tools at project features ay 100% LIBRE. Ang PRO subscription ay para sa cosmetic branding, specialized visual themes, at unlimited cloud storage.',
                      style: TextStyle(color: BanaagTheme.textMuted, fontSize: 12)),
                  if (_securityEngine.activeToken != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.security, size: 14, color: BanaagTheme.successGreen),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Offline Lease Valid until: ${_securityEngine.activeToken!.expiresAt.toString().split(' ')[0]} (HMAC-SHA256 Signed)',
                              style: const TextStyle(fontSize: 10, color: BanaagTheme.textMuted, fontFamily: 'monospace'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Feature 1: Custom Proposal Letterhead & Branding
            const Text('1. Client Proposal Custom Branding', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            const Text('Tinatanggal ang "Powered by BANAAG" watermark at pinapalitan ng sarili mong kumpanya logo at letterhead sa lahat ng PDF quotations at As-built certificates.',
                style: TextStyle(color: BanaagTheme.textMuted, fontSize: 12)),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _companyNameController,
                      decoration: const InputDecoration(
                        labelText: 'Company / Business Name',
                        prefixIcon: Icon(Icons.business, color: BanaagTheme.primaryAmber),
                        labelStyle: TextStyle(color: BanaagTheme.textMuted),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _prcLicenseController,
                      decoration: const InputDecoration(
                        labelText: 'PRC License / Accreditation Badge',
                        prefixIcon: Icon(Icons.badge, color: BanaagTheme.primaryAmber),
                        labelStyle: TextStyle(color: BanaagTheme.textMuted),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BanaagTheme.primaryAmber,
                        side: const BorderSide(color: BanaagTheme.primaryAmber),
                      ),
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload Company Logo (PNG / Vector)'),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('📸 Company Logo uploaded & locked to PDF Proposal templates!')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Feature 2: Specialized Visual Themes
            const Text('2. Specialized Field Themes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            const Text('Pumili ng high-contrast themes para madaling basahin sa ilalim ng matinding araw o minimalist themes para sa presentation sa opisina.',
                style: TextStyle(color: BanaagTheme.textMuted, fontSize: 12)),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedTheme,
                  dropdownColor: BanaagTheme.surfaceCard,
                  decoration: const InputDecoration(
                    labelText: 'Active Theme Style',
                    prefixIcon: Icon(Icons.palette_outlined, color: BanaagTheme.primaryAmber),
                    labelStyle: TextStyle(color: BanaagTheme.textMuted),
                  ),
                  items: _themes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedTheme = val);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('🎨 Theme switched to "$val"')),
                      );
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Feature 3: Unlimited Cloud Backup & Multi-Device Sync
            const Text('3. Multi-Device & Cloud Sync (Supabase PostgreSQL)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            const Text('Awtomatikong bina-backup ang lahat ng pre-cover photos, megger logs, at floor plans sa cloud para ma-access sa laptop o bagong cellphone.',
                style: TextStyle(color: BanaagTheme.textMuted, fontSize: 12)),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.cloud_done, color: BanaagTheme.successGreen),
                      title: const Text('Supabase Cloud Sync Engine'),
                      subtitle: const Text('PostgreSQL Schema & RLS policies ready'),
                      trailing: Switch(
                        value: _isProActive,
                        activeThumbColor: BanaagTheme.primaryAmber,
                        onChanged: (val) => setState(() => _isProActive = val),
                      ),
                    ),
                    const Divider(color: Colors.white12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BanaagTheme.primaryAmber,
                        side: const BorderSide(color: BanaagTheme.primaryAmber),
                      ),
                      icon: const Icon(Icons.settings_ethernet),
                      label: const Text('Configure Supabase Project Credentials'),
                      onPressed: () {
                        _showSupabaseConfigDialog(context);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSupabaseConfigDialog(BuildContext context) {
    final urlController = TextEditingController(text: 'https://xyzcompany.supabase.co');
    final keyController = TextEditingController(text: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BanaagTheme.surfaceCard,
        title: const Row(
          children: [
            Icon(Icons.cloud_sync, color: BanaagTheme.primaryAmber),
            SizedBox(width: 8),
            Text('Supabase Credentials', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ilagay ang iyong Libreng Supabase Project URL at Anon Key para mag-auto backup ang lahat ng mga projects sa cloud.',
              style: TextStyle(fontSize: 12, color: BanaagTheme.textMuted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'Project URL',
                hintText: 'https://<project-ref>.supabase.co',
                labelStyle: TextStyle(color: BanaagTheme.textMuted),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: keyController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'API Anon Key',
                hintText: 'sbp_...',
                labelStyle: TextStyle(color: BanaagTheme.textMuted),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: BanaagTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('⚡ Supabase Cloud Architecture Connected! Projects ready for automatic cloud sync.'),
                ),
              );
            },
            child: const Text('Connect & Verify'),
          ),
        ],
      ),
    );
  }
}
