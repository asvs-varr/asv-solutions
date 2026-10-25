// BANAAG Payment Repository
// Handles zero-typing screenshot-only GCash proof upload to Supabase
// with base64 image sync, local persistence, and master admin review.

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/payment_submission.dart';

class PaymentRepository {
  static const String _storageKey = 'banaag_payment_submissions_v1';
  static final PaymentRepository instance = PaymentRepository._();
  PaymentRepository._();

  static const String _supabaseUrl = 'https://cvuympdpkbuftqdzlwrw.supabase.co';
  static const String _anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN2dXltcGRwa2J1ZnRxZHpsd3J3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI2NjIxNDYsImV4cCI6MjEwODIzODE0Nn0.sQkiMvyy0quSnG8lW-O12uAsvnTWpyby9ZBciLl8bvU';

  List<PaymentSubmission> _cached = [];
  bool _isLoaded = false;

  Future<List<PaymentSubmission>> getSubmissions() async {
    if (_isLoaded) return List.unmodifiable(_cached);

    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(jsonString);
        _cached = list.map((item) => PaymentSubmission.fromJson(item as Map<String, dynamic>)).toList();
      } catch (_) {
        _cached = [];
      }
    } else {
      _cached = [];
    }
    _isLoaded = true;
    return List.unmodifiable(_cached);
  }

  /// Checks if an email currently has a pending proof submission
  Future<bool> hasPendingSubmission(String email) async {
    final list = await getSubmissions();
    return list.any((s) => s.email == email.trim().toLowerCase() && s.status == 'PENDING');
  }

  /// Submits GCash payment proof: compresses image to Base64 and uploads to cloud
  Future<bool> submitPaymentProof({
    required String email,
    required String packageType,
    required String localReceiptPath,
  }) async {
    final sanitizedEmail = email.trim().toLowerCase();
    final submissionId = 'SUB_${DateTime.now().millisecondsSinceEpoch}';

    // 1. Read and encode image to base64
    String base64Image = '';
    try {
      final file = File(localReceiptPath);
      if (file.existsSync()) {
        final bytes = await file.readAsBytes();
        base64Image = base64Encode(bytes);
      }
    } catch (_) {}

    final submission = PaymentSubmission(
      id: submissionId,
      email: sanitizedEmail,
      packageType: packageType,
      referenceNo: 'PHOTO_RECEIPT',
      localReceiptPath: localReceiptPath,
      status: 'PENDING',
      submittedAt: DateTime.now(),
    );

    // Save locally
    await getSubmissions();
    _cached.removeWhere((s) => s.email == sanitizedEmail && s.status == 'PENDING');
    _cached.insert(0, submission);
    await _persist();

    // 2. Broadcast to cloud via Supabase project_vouchers table
    // code format: PROOF_V2|email|packageType|timestamp
    // redeemed_by_email stores the base64 image data payload for admin inspection
    try {
      final code = 'PROOF_V2|$sanitizedEmail|$packageType|${DateTime.now().millisecondsSinceEpoch}';
      final url = Uri.parse('$_supabaseUrl/rest/v1/project_vouchers');
      await http.post(
        url,
        headers: {
          'apikey': _anonKey,
          'Authorization': 'Bearer $_anonKey',
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal',
        },
        body: jsonEncode({
          'code': code,
          'credits_amount': 1,
          'is_redeemed': false,
          'redeemed_by_email': base64Image.isNotEmpty ? base64Image : sanitizedEmail,
        }),
      );
    } catch (_) {}

    return true;
  }

  /// Fetches all cloud submissions (for Master Admin)
  Future<List<Map<String, dynamic>>> fetchCloudSubmissions() async {
    try {
      final url = Uri.parse('$_supabaseUrl/rest/v1/project_vouchers?code=like.PROOF*&order=created_at.desc');
      final response = await http.get(
        url,
        headers: {
          'apikey': _anonKey,
          'Authorization': 'Bearer $_anonKey',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        return list.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Approves a submission: creates a real unlocked slot voucher in cloud, redeems it for user, and marks proof as verified
  Future<Map<String, dynamic>> approveSubmission({
    required String cloudVoucherId,
    required String userEmail,
  }) async {
    final sanitizedEmail = userEmail.trim().toLowerCase();
    final randomSuffix = (DateTime.now().millisecondsSinceEpoch % 9000 + 1000).toString();
    final newVoucherCode = 'SLOT-$randomSuffix';

    try {
      // 1. Create official unlocked voucher in Supabase
      final urlCreate = Uri.parse('$_supabaseUrl/rest/v1/project_vouchers');
      final respCreate = await http.post(
        urlCreate,
        headers: {
          'apikey': _anonKey,
          'Authorization': 'Bearer $_anonKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'code': newVoucherCode,
          'credits_amount': 1,
          'is_redeemed': true, // Directly marked as redeemed and credited
          'redeemed_by_email': sanitizedEmail,
          'redeemed_at': DateTime.now().toIso8601String(),
        }),
      );

      if (respCreate.statusCode != 201 && respCreate.statusCode != 200) {
        return {'success': false, 'message': 'Failed to credit slot in database.'};
      }

      // 2. Delete the pending proof record from project_vouchers to clean up queue
      final urlDelProof = Uri.parse('$_supabaseUrl/rest/v1/project_vouchers?id=eq.$cloudVoucherId');
      await http.delete(
        urlDelProof,
        headers: {
          'apikey': _anonKey,
          'Authorization': 'Bearer $_anonKey',
        },
      );

      // 3. Update local cache
      await getSubmissions();
      final index = _cached.indexWhere((s) => s.email == sanitizedEmail);
      if (index != -1) {
        _cached[index] = _cached[index].copyWith(status: 'APPROVED', approvedVoucherCode: newVoucherCode);
        await _persist();
      }

      return {
        'success': true,
        'voucherCode': newVoucherCode,
        'message': 'Successfully approved! 1 Project Slot has been credited to $sanitizedEmail.',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error approving submission: $e'};
    }
  }

  /// Rejects a submission
  Future<void> rejectSubmission({
    required String cloudVoucherId,
    required String userEmail,
  }) async {
    final sanitizedEmail = userEmail.trim().toLowerCase();
    try {
      final url = Uri.parse('$_supabaseUrl/rest/v1/project_vouchers?id=eq.$cloudVoucherId');
      await http.delete(
        url,
        headers: {
          'apikey': _anonKey,
          'Authorization': 'Bearer $_anonKey',
        },
      );
    } catch (_) {}

    await getSubmissions();
    final index = _cached.indexWhere((s) => s.email == sanitizedEmail);
    if (index != -1) {
      _cached[index] = _cached[index].copyWith(status: 'REJECTED');
      await _persist();
    }
  }

  /// Fetches all active Pro users with credited slots
  Future<List<Map<String, dynamic>>> fetchActiveProUsers() async {
    try {
      final url = Uri.parse('$_supabaseUrl/rest/v1/project_vouchers?is_redeemed=eq.true&order=redeemed_at.desc');
      final response = await http.get(
        url,
        headers: {
          'apikey': _anonKey,
          'Authorization': 'Bearer $_anonKey',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        // Exclude internal proof submissions, group by user email
        final activeList = list.where((v) {
          final code = (v['code'] as String? ?? '');
          return !code.startsWith('PROOF|') && !code.startsWith('PROOF_V2|');
        }).toList();

        final Map<String, Map<String, dynamic>> userMap = {};
        for (var item in activeList) {
          final email = (item['redeemed_by_email'] as String? ?? '').trim().toLowerCase();
          if (email.isEmpty) continue;
          if (!userMap.containsKey(email)) {
            userMap[email] = {
              'email': email,
              'total_slots': 0,
              'vouchers': <String>[],
              'last_active': item['redeemed_at'] ?? item['created_at'],
            };
          }
          userMap[email]!['total_slots'] = (userMap[email]!['total_slots'] as int) + 1;
          (userMap[email]!['vouchers'] as List<String>).add(item['code'] as String? ?? 'SLOT');
        }
        return userMap.values.toList();
      }
    } catch (_) {}
    return [];
  }

  /// Revokes a user's license by deleting or invalidating all active vouchers credited to their email
  Future<Map<String, dynamic>> revokeUserAccess({required String userEmail}) async {
    final sanitizedEmail = userEmail.trim().toLowerCase();
    try {
      // 1. Invalidate or delete all credited project_vouchers for this email in Supabase
      final url = Uri.parse('$_supabaseUrl/rest/v1/project_vouchers?redeemed_by_email=eq.$sanitizedEmail');
      await http.delete(
        url,
        headers: {
          'apikey': _anonKey,
          'Authorization': 'Bearer $_anonKey',
        },
      );

      // 2. Also ensure licensed_buyers status is marked REVOKED if table exists
      try {
        final urlLicensed = Uri.parse('$_supabaseUrl/rest/v1/licensed_buyers?email=eq.$sanitizedEmail');
        await http.patch(
          urlLicensed,
          headers: {
            'apikey': _anonKey,
            'Authorization': 'Bearer $_anonKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'status': 'REVOKED'}),
        );
      } catch (_) {}

      // 3. Update local cache
      await getSubmissions();
      _cached.removeWhere((s) => s.email == sanitizedEmail);
      await _persist();

      return {
        'success': true,
        'message': 'Successfully revoked all active slots for $sanitizedEmail.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error revoking user access: $e',
      };
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _cached.map((t) => t.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(list));
  }
}
