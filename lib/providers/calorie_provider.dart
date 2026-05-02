import 'package:flutter/foundation.dart';
import '../models/food_log.dart';
import '../models/food_item.dart';
import '../services/storage_service.dart';
import 'package:uuid/uuid.dart';

class CalorieProvider extends ChangeNotifier {
  final StorageService _storage;
  List<FoodLog> _todayLogs = [];
  bool _loading = false;
  DateTime _selectedDate = DateTime.now();

  CalorieProvider(this._storage);

  List<FoodLog> get logs => _todayLogs;
  bool get loading => _loading;
  DateTime get selectedDate => _selectedDate;

  List<FoodLog> get breakfast => _todayLogs.where((l) => l.mealType == 'breakfast').toList();
  List<FoodLog> get lunch     => _todayLogs.where((l) => l.mealType == 'lunch').toList();
  List<FoodLog> get dinner    => _todayLogs.where((l) => l.mealType == 'dinner').toList();
  List<FoodLog> get snacks    => _todayLogs.where((l) => l.mealType == 'snack').toList();

  double get totalCalories => _todayLogs.fold(0, (s, l) => s + l.calories);
  double get totalProtein  => _todayLogs.fold(0, (s, l) => s + l.protein);
  double get totalCarbs    => _todayLogs.fold(0, (s, l) => s + l.carbs);
  double get totalFat      => _todayLogs.fold(0, (s, l) => s + l.fat);

  Future<void> loadToday() async {
    _loading = true;
    notifyListeners();
    _todayLogs = await _storage.getLogsForDate(_selectedDate);
    _loading = false;
    notifyListeners();
  }

  Future<void> addFood({
    required FoodItem food,
    required double quantity,
    required String mealType,
  }) async {
    final log = FoodLog(
      id: const Uuid().v4(),
      foodItem: food,
      quantity: quantity,
      mealType: mealType,
      loggedAt: DateTime.now(),
    );
    await _storage.addLog(log);
    await loadToday();
  }

  Future<void> removeFood(String logId) async {
    await _storage.removeLog(logId);
    await loadToday();
  }

  Future<List<FoodLog>> getWeeklyLogs() async {
    final logs = <FoodLog>[];
    for (int i = 6; i >= 0; i--) {
      final day = DateTime.now().subtract(Duration(days: i));
      final dayLogs = await _storage.getLogsForDate(day);
      logs.addAll(dayLogs);
    }
    return logs;
  }
}