// BANAAG Dev Ticket Repository: Local JSON & SharedPreferences persistence

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/dev_ticket.dart';

class DevTicketRepository {
  static const String _storageKey = 'banaag_dev_tickets_v1';
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

  Future<void> saveTicket(DevTicket ticket) async {
    await getTickets();
    _cachedTickets.insert(0, ticket);
    await _persist();
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
