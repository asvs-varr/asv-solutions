// BANAAG Dev Ticket Repository: Local JSON & Supabase Cloud persistence
// Automatically synchronizes user bug reports and feature tickets with Master Admin.

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/dev_ticket.dart';
import '../domain/banaag_auth_service.dart';

class DevTicketRepository {
  static const String _storageKey = 'banaag_dev_tickets_v1';
  static const String _supabaseUrl = 'https://cvuympdpkbuftqdzlwrw.supabase.co';
  static const String _anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN2dXltcGRwa2J1ZnRxZHpsd3J3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI2NjIxNDYsImV4cCI6MjEwODIzODE0Nn0.sQkiMvyy0quSnG8lW-O12uAsvnTWpyby9ZBciLl8bvU';

  static final DevTicketRepository instance = DevTicketRepository._();
  DevTicketRepository._();

  List<DevTicket> _cachedTickets = [];
  bool _isLoaded = false;

  Future<List<DevTicket>> getTickets() async {
    if (_isLoaded) return List.unmodifiable(_cachedTickets);

    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(jsonString);
        _cachedTickets = list.map((item) => DevTicket.fromJson(item as Map<String, dynamic>)).toList();
      } catch (_) {
        _cachedTickets = [];
      }
    } else {
      _cachedTickets = [];
    }
    _isLoaded = true;
    return List.unmodifiable(_cachedTickets);
  }

  /// Saves ticket locally and syncs to Supabase Cloud for Master Admin inspection
  Future<void> saveTicket(DevTicket ticket) async {
    await getTickets();
    _cachedTickets.insert(0, ticket);
    await _persist();

    // Broadcast to Cloud Supabase
    try {
      final userEmail = BanaagAuthService.instance.currentUser?.email.trim().toLowerCase() ?? 'anonymous@contractor.ph';
      
      // Read first attached image if any and encode to base64
      String base64Image = '';
      if (ticket.imageUris.isNotEmpty) {
        try {
          final file = File(ticket.imageUris.first);
          if (file.existsSync()) {
            final bytes = await file.readAsBytes();
            base64Image = base64Encode(bytes);
          }
        } catch (_) {}
      }

      final payloadMap = {
        'id': ticket.id,
        'title': ticket.title,
        'description': ticket.description,
        'type': ticket.type,
        'priority': ticket.priority,
        'projectContext': ticket.projectContext,
        'userEmail': userEmail,
        'createdAt': ticket.createdAt.toIso8601String(),
        'image': base64Image,
      };

      final payloadJson = jsonEncode(payloadMap);
      final code = 'TICKET|$userEmail|${ticket.type}|${ticket.priority}|${DateTime.now().millisecondsSinceEpoch}';

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
          'credits_amount': 0, // Dev ticket marker
          'is_redeemed': false, // false = Open ticket, true = Resolved
          'redeemed_by_email': payloadJson,
        }),
      );
    } catch (_) {}
  }

  /// Fetches all cloud tickets for Master Admin Panel
  Future<List<Map<String, dynamic>>> fetchCloudTickets() async {
    try {
      final url = Uri.parse('$_supabaseUrl/rest/v1/project_vouchers?code=like.TICKET*&order=created_at.desc');
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

  /// Marks a ticket as resolved/closed in Cloud
  Future<bool> resolveCloudTicket(String cloudId) async {
    try {
      final url = Uri.parse('$_supabaseUrl/rest/v1/project_vouchers?id=eq.$cloudId');
      final response = await http.patch(
        url,
        headers: {
          'apikey': _anonKey,
          'Authorization': 'Bearer $_anonKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'is_redeemed': true}),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  Future<void> updateTicketStatus(String id, String status, {String? resolutionSummary}) async {
    await getTickets();
    final index = _cachedTickets.indexWhere((t) => t.id == id);
    if (index != -1) {
      _cachedTickets[index] = _cachedTickets[index].copyWith(
        status: status,
        resolutionSummary: resolutionSummary,
      );
      await _persist();
    }
  }

  Future<void> deleteTicket(String id) async {
    await getTickets();
    _cachedTickets.removeWhere((t) => t.id == id);
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _cachedTickets.map((t) => t.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(list));
  }
}
