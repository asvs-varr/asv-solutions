// BANAAG Payment Repository
// Handles cloud submission to Supabase (via project_vouchers metadata bridge)
// and offline-first local persistence.

import 'dart:convert';
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

  /// Submits GCash payment proof to both cloud (Supabase) and local cache
  Future<bool> submitPayment({
    required String email,
    required String packageType,
    required String referenceNo,
    required String localReceiptPath,
  }) async {
    final submissionId = 'SUB_${DateTime.now().millisecondsSinceEpoch}';
    final submission = PaymentSubmission(
      id: submissionId,
      email: email.trim().toLowerCase(),
      packageType: packageType,
      referenceNo: referenceNo.trim(),
      localReceiptPath: localReceiptPath,
      status: 'PENDING',
      submittedAt: DateTime.now(),
    );

    // Save locally
    await getSubmissions();
    _cached.insert(0, submission);
    await _persist();

    // Broadcast to cloud via Supabase project_vouchers metadata bridge
    try {
      final code = 'PROOF|${submission.email}|${submission.referenceNo}|${submission.packageType}';
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
          'credits_amount': packageType == 'BASE_PACK_100' ? 1 : 1,
          'is_redeemed': false,
          'redeemed_by_email': submission.email,
        }),
      );
    } catch (_) {}

    return true;
  }

  /// Fetches all cloud submissions (for Master Admin)
  Future<List<Map<String, dynamic>>> fetchCloudSubmissions() async {
    try {
      final url = Uri.parse('$_supabaseUrl/rest/v1/project_vouchers?code=like.PROOF|*&order=created_at.desc');
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

  /// Approves a submission: generates an active slot voucher, redeems it, and deletes the pending proof record
  Future<Map<String, dynamic>> approveSubmission({
    required String cloudVoucherId,
    required String userEmail,
    required String proofCode,
  }) async {
    final randomSuffix = (DateTime.now().millisecondsSinceEpoch % 9000 + 1000).toString();
    final newVoucherCode = 'SLOT-$randomSuffix';

    try {
      // 1. Create official voucher in Supabase
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
          'is_redeemed': false,
        }),
      );

      if (respCreate.statusCode != 201 && respCreate.statusCode != 200) {
        return {'success': false, 'message': 'Failed to generate voucher code'};
      }

      // 2. Automatically redeem it on behalf of the customer
      final urlRedeem = Uri.parse('$_supabaseUrl/rest/v1/rpc/redeem_project_voucher');
      final respRedeem = await http.post(
        urlRedeem,
        headers: {
          'apikey': _anonKey,
          'Authorization': 'Bearer $_anonKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'p_email': userEmail,
          'p_code': newVoucherCode,
        }),
      );

      // 3. Mark the proof voucher record as redeemed/completed
      final urlPatchProof = Uri.parse('$_supabaseUrl/rest/v1/project_vouchers?id=eq.$cloudVoucherId');
      await http.patch(
        urlPatchProof,
        headers: {
          'apikey': _anonKey,
          'Authorization': 'Bearer $_anonKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'is_redeemed': true,
          'redeemed_at': DateTime.now().toIso8601String(),
        }),
      );

      // Update local cache
      await getSubmissions();
      final index = _cached.indexWhere((s) => s.email == userEmail);
      if (index != -1) {
        _cached[index] = _cached[index].copyWith(status: 'APPROVED', approvedVoucherCode: newVoucherCode);
        await _persist();
      }

      return {
        'success': true,
        'voucherCode': newVoucherCode,
        'message': 'Successfully approved! +1 Project slot credited to $userEmail (Voucher: $newVoucherCode)',
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
    final index = _cached.indexWhere((s) => s.email == userEmail);
    if (index != -1) {
      _cached[index] = _cached[index].copyWith(status: 'REJECTED');
      await _persist();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _cached.map((t) => t.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(list));
  }
}
