// BANAAG Master Admin Verification Screen
// Dual-Tab Management:
// Tab 1: Pending GCash Proofs (Image inspection with 1-tap Approve & Reject)
// Tab 2: Active Pro Users (Overview of active slots with 1-tap Soft Revoke)

import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme/banaag_theme.dart';
import '../../data/payment_repository.dart';

class AdminVerificationScreen extends StatefulWidget {
  const AdminVerificationScreen({super.key});

  @override
  State<AdminVerificationScreen> createState() => _AdminVerificationScreenState();
}

class _AdminVerificationScreenState extends State<AdminVerificationScreen>
    with SingleTickerProviderStateMixin {
  final _repo = PaymentRepository.instance;
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _cloudSubmissions = [];
  List<Map<String, dynamic>> _activeProUsers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final subs = await _repo.fetchCloudSubmissions();
    final pros = await _repo.fetchActiveProUsers();
    if (mounted) {
      setState(() {
        _cloudSubmissions = subs;
        _activeProUsers = pros;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleApprove(Map<String, dynamic> item) async {
    final cloudId = item['id'] as String;
    final code = item['code'] as String;
    final parts = code.split('|');
    final userEmail = parts.length > 1 ? parts[1] : (item['redeemed_by_email'] ?? '');

    setState(() => _isLoading = true);
    final res = await _repo.approveSubmission(
      cloudVoucherId: cloudId,
      userEmail: userEmail,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Processed!'),
          backgroundColor: res['success'] == true ? const Color(0xFF10B981) : Colors.redAccent,
        ),
      );
      _loadAll();
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
      _loadAll();
    }
  }

  Future<void> _confirmRevokeUser(String email) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2430),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Revoke Pro Access?',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to revoke Pro access for $email?\n\n'
          '• Their remaining project credits will be reset to 0.\n'
          '• They will be barred from creating new projects unless they purchase again.\n'
          '• Existing local projects will remain viewable in read-only mode.',
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Revoke', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      final res = await _repo.revokeUserAccess(userEmail: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'User access revoked.'),
            backgroundColor: res['success'] == true ? Colors.redAccent : Colors.orange,
          ),
        );
        _loadAll();
      }
    }
  }

  void _showFullReceipt(BuildContext context, ImageProvider imageProvider, String email) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF141822),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'GCash Receipt: $email',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Container(
                color: Colors.black,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Image(image: imageProvider, fit: BoxFit.contain),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1218),
      appBar: AppBar(
        title: const Text('Master Admin Panel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: const Color(0xFF141822),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: BanaagTheme.primaryAmber,
          indicatorWeight: 3,
          labelColor: BanaagTheme.primaryAmber,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Pending Proofs'),
                  if (_cloudSubmissions.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_cloudSubmissions.length}',
                        style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Active Pro Users'),
                  if (_activeProUsers.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_activeProUsers.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: BanaagTheme.primaryAmber))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPendingProofsTab(),
                _buildActiveProUsersTab(),
              ],
            ),
    );
  }

  Widget _buildPendingProofsTab() {
    if (_cloudSubmissions.isEmpty) {
      return Center(
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
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _cloudSubmissions.length,
      itemBuilder: (ctx, i) {
        final item = _cloudSubmissions[i];
        final code = item['code'] as String? ?? '';
        final parts = code.split('|');
        final email = parts.length > 1 ? parts[1] : (item['redeemed_by_email'] ?? 'Unknown');
        final pkg = parts.length > 2 ? parts[2] : 'BASE_PACK_100';
        final isRedeemed = item['is_redeemed'] == true;
        final payloadData = item['redeemed_by_email'] as String? ?? '';

        ImageProvider? receiptImage;
        if (payloadData.length > 200) {
          try {
            receiptImage = MemoryImage(base64Decode(payloadData));
          } catch (_) {}
        }

        return Card(
          color: const Color(0xFF1E2638),
          margin: const EdgeInsets.only(bottom: 16),
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: pkg == 'TOPUP_50' ? Colors.blue.withValues(alpha: 0.2) : BanaagTheme.primaryAmber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: pkg == 'TOPUP_50' ? Colors.blueAccent : BanaagTheme.primaryAmber,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            pkg == 'TOPUP_50' ? '₱50 TOP-UP' : '₱100 BASE PACK',
                            style: TextStyle(
                              color: pkg == 'TOPUP_50' ? Colors.blueAccent : BanaagTheme.primaryAmber,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isRedeemed ? '✓ APPROVED' : '⏳ PENDING REVIEW',
                          style: TextStyle(
                            color: isRedeemed ? const Color(0xFF10B981) : Colors.orangeAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      item['created_at'] != null ? (item['created_at'] as String).substring(0, 10) : '',
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.email_outlined, size: 16, color: BanaagTheme.primaryAmber),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        email,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (receiptImage != null)
                  GestureDetector(
                    onTap: () => _showFullReceipt(context, receiptImage!, email),
                    child: Container(
                      height: 160,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image(image: receiptImage, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                          Container(
                            color: Colors.black38,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.zoom_in, color: Colors.white, size: 18),
                                SizedBox(width: 6),
                                Text('Tap to inspect full receipt', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.white60),
                        SizedBox(width: 8),
                        Text('Screenshot not attached in legacy payload', style: TextStyle(color: Colors.white60, fontSize: 11)),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                if (!isRedeemed)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _handleReject(item),
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Reject', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _handleApprove(item),
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Approve & Unlock', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveProUsersTab() {
    if (_activeProUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_outlined, color: Colors.grey.withValues(alpha: 0.5), size: 64),
            const SizedBox(height: 12),
            const Text('No Active Pro Users Yet', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 4),
            const Text('Approved users will appear here.', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _activeProUsers.length,
      itemBuilder: (ctx, i) {
        final user = _activeProUsers[i];
        final email = user['email'] as String? ?? '';
        final totalSlots = user['total_slots'] as int? ?? 1;
        final vouchers = (user['vouchers'] as List<dynamic>?) ?? [];
        final lastActive = user['last_active'] as String? ?? '';

        return Card(
          color: const Color(0xFF1E2638),
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFF2A364F)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF10B981), width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified, color: Color(0xFF10B981), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'PRO ($totalSlots Slot${totalSlots > 1 ? 's' : ''})',
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (lastActive.isNotEmpty)
                      Text(
                        lastActive.length >= 10 ? lastActive.substring(0, 10) : lastActive,
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.account_circle, size: 20, color: BanaagTheme.primaryAmber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        email,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Credited Vouchers: ${vouchers.join(', ')}',
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent, width: 1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _confirmRevokeUser(email),
                    icon: const Icon(Icons.block, size: 16),
                    label: const Text('Revoke Pro License', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
