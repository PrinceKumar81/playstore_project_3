import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/food_item.dart';

class IndianFoodService {
  static List<FoodItem>? _cache;

  static Future<List<FoodItem>> getAll() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/data/indian_foods.json');
    final list = jsonDecode(raw) as List;
    _cache = list.map((e) => FoodItem.fromJson(e)).toList();
    return _cache!;
  }

  static Future<List<FoodItem>> search(String query) async {
    final all = await getAll();
    final q = query.toLowerCase();
    return all.where((f) =>
    f.name.toLowerCase().contains(q) ||
        f.category.toLowerCase().contains(q)
    ).toList();
  }

  static Future<FoodItem?> findById(String id) async {
    final all = await getAll();
    try {
      return all.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }
}