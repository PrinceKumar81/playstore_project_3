import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/food_item.dart';

class OpenFoodFactsService {
  static const _baseUrl = 'https://world.openfoodfacts.org';

  static Future<FoodItem?> fetchByBarcode(String barcode) async {
    try {
      final url = Uri.parse('$_baseUrl/api/v0/product/$barcode.json');
      final res = await http.get(url, headers: {'User-Agent': 'SmartCalorieApp/1.0'})
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      if (data['status'] != 1) return null;
      return _parseProduct(data['product'], barcode);
    } catch (_) {
      return null;
    }
  }

  static Future<List<FoodItem>> searchByName(String query) async {
    try {
      final url = Uri.parse(
          '$_baseUrl/cgi/search.pl?search_terms=${Uri.encodeComponent(query)}'
              '&search_simple=1&action=process&json=1&page_size=10'
      );
      final res = await http.get(url, headers: {'User-Agent': 'SmartCalorieApp/1.0'})
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body);
      final products = data['products'] as List? ?? [];
      return products
          .map((p) => _parseProduct(p, null))
          .where((f) => f != null)
          .cast<FoodItem>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  static FoodItem? _parseProduct(Map<String, dynamic> p, String? barcode) {
    try {
      final n = p['nutriments'] ?? {};
      final name = p['product_name'] ?? p['product_name_en'] ?? '';
      if (name.isEmpty) return null;
      final cal = (n['energy-kcal_100g'] ?? n['energy_100g'] ?? 0).toDouble();
      // Parse ingredients
      final ingredRaw = p['ingredients_text'] ?? p['ingredients_text_en'] ?? '';
      final ingreds = ingredRaw.isNotEmpty
          ? ingredRaw.split(RegExp(r'[,;]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
          : null;

      return FoodItem(
        id: 'off_${barcode ?? name.hashCode}',
        name: name,
        category: p['categories_tags']?.first?.replaceAll('en:', '') ?? 'Packaged',
        caloriesPer100g: cal,
        protein: (n['proteins_100g'] ?? 0).toDouble(),
        carbs: (n['carbohydrates_100g'] ?? 0).toDouble(),
        fat: (n['fat_100g'] ?? 0).toDouble(),
        fiber: (n['fiber_100g'] ?? 0).toDouble(),
        sugar: (n['sugars_100g'] ?? 0).toDouble(),
        sodium: (n['sodium_100g'] ?? 0) * 1000, // convert kg to mg
        servingSize: (p['serving_quantity'] ?? 100).toDouble(),
        servingUnit: 'g',
        servingLabel: p['serving_size'] ?? '100g',
        brand: p['brands'],
        imageUrl: p['image_front_small_url'] ?? p['image_url'],
        ingredients: ingreds?.cast<String>(),
        barcode: barcode,
        icon: '📦',
      );
    } catch (_) {
      return null;
    }
  }
}