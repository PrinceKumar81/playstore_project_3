import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/food_log.dart';
import '../models/user_profile.dart';

class StorageService {
  static const _logsKey = 'food_logs';
  static const _profileKey = 'user_profile';
  static StorageService? _instance;
  late SharedPreferences _prefs;

  StorageService._();

  static Future<StorageService> getInstance() async {
    if (_instance == null) {
      _instance = StorageService._();
      _instance!._prefs = await SharedPreferences.getInstance();
    }
    return _instance!;
  }

  // ── Food Logs ──────────────────────────────────────────────────
  Future<List<FoodLog>> getLogs() async {
    final raw = _prefs.getString(_logsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => FoodLog.fromJson(e)).toList();
  }

  Future<List<FoodLog>> getLogsForDate(DateTime date) async {
    final all = await getLogs();
    return all.where((l) =>
    l.loggedAt.year == date.year &&
        l.loggedAt.month == date.month &&
        l.loggedAt.day == date.day
    ).toList();
  }

  Future<void> addLog(FoodLog log) async {
    final all = await getLogs();
    all.add(log);
    await _saveLogs(all);
  }

  Future<void> removeLog(String id) async {
    final all = await getLogs();
    all.removeWhere((l) => l.id == id);
    await _saveLogs(all);
  }

  Future<void> _saveLogs(List<FoodLog> logs) async {
    // Keep only last 30 days
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final filtered = logs.where((l) => l.loggedAt.isAfter(cutoff)).toList();
    await _prefs.setString(_logsKey, jsonEncode(filtered.map((l) => l.toJson()).toList()));
  }

  // ── User Profile ───────────────────────────────────────────────
  Future<UserProfile> getProfile() async {
    final raw = _prefs.getString(_profileKey);
    if (raw == null) return UserProfile.defaultProfile();
    return UserProfile.fromJson(jsonDecode(raw));
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _prefs.setString(_profileKey, jsonEncode(profile.toJson()));
  }
}