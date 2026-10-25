// BANAAG Master Admin Verification Screen
// Accessible only to verified admin accounts (vincentjamitoarrogante@gmail.com / mr.arvin03@gmail.com)
// Displays pending GCash payment submissions with 1-tap Approve & Reject actions.

import 'package:flutter/material.dart';
import '../theme/banaag_theme.dart';
import '../../data/payment_repository.dart';

class AdminVerificationScreen extends StatefulWidget {
  const AdminVerificationScreen({super.key});

  @override
  State<AdminVerificationScreen> createState() => _AdminVerificationScreenState();
}

class _AdminVerificationScreenState extends State<AdminVerificationScreen> {
  final _repo = PaymentRepository.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _cloudSubmissions = [];

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  Future<void> _loadQueue() async {
    setState(() => _isLoading = true);
    final list = await _repo.fetchCloudSubmissions();
    if (mounted) {
      setState(() {
        _cloudSubmissions = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleApprove(Map<String, dynamic> item) async {
    final cloudId = item['id'] as String;
    final code = item['code'] as String;
    // format: PROOF|email|refNo|packageType
    final parts = code.split('|');
    final userEmail = parts.length > 1 ? parts[1] : (item['redeemed_by_email'] ?? '');

    setState(() => _isLoading = true);
    final res = await _repo.approveSubmission(
      cloudVoucherId: cloudId,
      userEmail: userEmail,
      proofCode: code,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Processed!'),
          backgroundColor: res['success'] == true ? const Color(0xFF10B981) : Colors.redAccent,
        ),
      );
      _loadQueue();
    }
  }

  Future<void> _handleReject(Map<String, dynamic> item) async {
    final cloudId = item['id'] as String;
    final code = item['code'] as String;
    final parts = code.split('|');
    final userEmail = parts.length > 1 ? parts[1] : (item['redeemed_by_email'] ?? '');

    setState(() => _isLoading = true);
    await _repo.rejectSubmission(
      cloudVoucherId: cloudId,
      userEmail: userEmail,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment rejected and submission removed.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      _loadQueue();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1219),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141822),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings, color: BanaagTheme.primaryAmber),
            SizedBox(width: 8),
            Text('Admin Payment Queue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadQueue,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: BanaagTheme.primaryAmber))
          : _cloudSubmissions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.done_all, color: Colors.grey.withValues(alpha: 0.5), size: 64),
                      const SizedBox(height: 12),
                      const Text('All pending GCash payments cleared!', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 4),
                      const Text('Zero pending verifications.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _cloudSubmissions.length,
                  itemBuilder: (ctx, i) {
                    final item = _cloudSubmissions[i];
                    final code = item['code'] as String? ?? '';
                    final parts = code.split('|');
                    final email = parts.length > 1 ? parts[1] : (item['redeemed_by_email'] ?? 'Unknown');
                    final refNo = parts.length > 2 ? parts[2] : 'N/A';
                    final pkg = parts.length > 3 ? parts[3] : 'BASE_PACK_100';
                    final isRedeemed = item['is_redeemed'] == true;

                    return Card(
                      color: const Color(0xFF1E2638),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isRedeemed ? Colors.green.withValues(alpha: 0.3) : const Color(0xFF2A364F),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: pkg.contains('BASE') ? const Color(0xFF007DFE) : const Color(0xFF10B981),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        pkg.contains('BASE') ? '₱100 BASE PACK' : '₱50 TOP-UP',
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isRedeemed ? '✓ APPROVED' : '⏳ PENDING',
                                      style: TextStyle(
                                        color: isRedeemed ? const Color(0xFF10B981) : Colors.amber,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  item['created_at'] != null ? item['created_at'].toString().substring(0, 10) : '',
                                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                                ),
                              ],
                            ),
                            const Divider(color: Color(0xFF2A364F), height: 20),
                            Row(
                              children: [
                                const Icon(Icons.email, color: Color(0xFF38BDF8), size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    email,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.receipt_long, color: Color(0xFFFFC107), size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'GCash Ref: $refNo',
                                  style: const TextStyle(color: Color(0xFFFFC107), fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                            if (!isRedeemed) ...[
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.redAccent,
                                        side: const BorderSide(color: Colors.redAccent),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: () => _handleReject(item),
                                      icon: const Icon(Icons.close, size: 16),
                                      label: const Text('Reject', style: TextStyle(fontSize: 12)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF10B981),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: () => _handleApprove(item),
                                      icon: const Icon(Icons.check, size: 16),
                                      label: const Text('Approve & Credit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
