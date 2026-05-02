import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/food_item.dart';

class OpenFoodFactsService {
  static const _baseUrl = 'https://world.openfoodfacts.org';
  static const _headers = {
    'User-Agent': 'SmartCalorieApp/1.0 (Flutter; contact@example.com)',
  };

  // ── Barcode Lookup ─────────────────────────────────────────────
  static Future<FoodItem?> fetchByBarcode(String barcode) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/api/v2/product/$barcode'
            '?fields=product_name,product_name_en,brands,categories_tags,'
            'nutriments,serving_size,serving_quantity,ingredients_text,'
            'ingredients_text_en,image_front_small_url,image_url',
      );
      final res = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      if (data['status'] != 1) return null;
      return _parseProduct(data['product'], barcode);
    } catch (_) {
      return null;
    }
  }

  // ── Name Search ────────────────────────────────────────────────
  static Future<List<FoodItem>> searchByName(String query) async {
    final v2Results = await _searchV2(query);
    if (v2Results.isNotEmpty) return v2Results;
    return _searchV1(query);
  }

  // v2 API — primary
  static Future<List<FoodItem>> _searchV2(String query) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/api/v2/search'
            '?search_terms=${Uri.encodeComponent(query)}'
            '&fields=product_name,product_name_en,brands,categories_tags,'
            'nutriments,serving_size,serving_quantity,ingredients_text,'
            'ingredients_text_en,image_front_small_url,code'
            '&page_size=20'
            '&sort_by=unique_scans_n',
      );
      final res = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body);
      final products = data['products'] as List? ?? [];
      return products
          .map((p) => _parseProduct(p as Map<String, dynamic>, p['code']?.toString()))
          .where((f) => f != null)
          .cast<FoodItem>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  // v1 CGI — fallback
  static Future<List<FoodItem>> _searchV1(String query) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/cgi/search.pl'
            '?search_terms=${Uri.encodeComponent(query)}'
            '&search_simple=1'
            '&action=process'
            '&json=1'
            '&page_size=20'
            '&sort_by=unique_scans_n',
      );
      final res = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body);
      final products = data['products'] as List? ?? [];
      return products
          .map((p) => _parseProduct(p as Map<String, dynamic>, p['code']?.toString()))
          .where((f) => f != null)
          .cast<FoodItem>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Parser ─────────────────────────────────────────────────────
  // ✅ Fixed: moved _num() out as a static helper — no nested functions
  static FoodItem? _parseProduct(Map<String, dynamic> p, String? barcode) {
    try {
      final n = p['nutriments'] as Map<String, dynamic>? ?? {};

      final name = (p['product_name_en'] ?? p['product_name'] ?? '')
          .toString()
          .trim();
      if (name.isEmpty) return null;

      final cal = _nutrientVal(n, 'energy-kcal_100g') > 0
          ? _nutrientVal(n, 'energy-kcal_100g')
          : _nutrientVal(n, 'energy_100g') / 4.184;

      // Parse ingredients
      final ingredRaw =
      (p['ingredients_text_en'] ?? p['ingredients_text'] ?? '').toString();
      final ingreds = ingredRaw.isNotEmpty
          ? ingredRaw
          .split(RegExp(r'[,;]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty && s.length < 60)
          .take(30)
          .toList()
          : null;

      // Parse category
      final cats = p['categories_tags'] as List?;
      final category = cats != null && cats.isNotEmpty
          ? _capitalize(
        cats.last.toString().replaceAll('en:', '').replaceAll('-', ' '),
      )
          : 'Packaged';

      // Parse serving
      final servingQty = p['serving_quantity'];
      final serving = servingQty != null
          ? (servingQty is num
          ? servingQty.toDouble()
          : double.tryParse(servingQty.toString()) ?? 100.0)
          : 100.0;

      return FoodItem(
        id: 'off_${barcode ?? name.hashCode}',
        name: name,
        category: category,
        caloriesPer100g: cal,
        protein:  _nutrientVal(n, 'proteins_100g'),
        carbs:    _nutrientVal(n, 'carbohydrates_100g'),
        fat:      _nutrientVal(n, 'fat_100g'),
        fiber:    _nutrientVal(n, 'fiber_100g'),
        sugar:    _nutrientVal(n, 'sugars_100g'),
        sodium:   _nutrientVal(n, 'sodium_100g') * 1000,
        servingSize:  serving,
        servingUnit:  'g',
        servingLabel: p['serving_size']?.toString() ?? '${serving.round()}g',
        brand:       p['brands']?.toString(),
        imageUrl:    (p['image_front_small_url'] ?? p['image_url'])?.toString(),
        ingredients: ingreds?.cast<String>(),
        barcode:     barcode,
        icon: _iconForCategory(category),
      );
    } catch (_) {
      return null;
    }
  }

  // ── Static Helpers ─────────────────────────────────────────────

  // ✅ Fixed: was a nested function — now a proper static method
  static double _nutrientVal(Map<String, dynamic> n, String key) {
    final v = n[key];
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static String _capitalize(String s) {
    return s
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  static String _iconForCategory(String category) {
    final c = category.toLowerCase();
    if (c.contains('chocolate') || c.contains('candy'))              return '🍫';
    if (c.contains('biscuit')   || c.contains('cookie'))             return '🍪';
    if (c.contains('beverage')  || c.contains('drink')
        || c.contains('juice'))               return '🥤';
    if (c.contains('dairy')     || c.contains('milk')
        || c.contains('cheese'))              return '🥛';
    if (c.contains('bread')     || c.contains('cereal'))             return '🍞';
    if (c.contains('chip')      || c.contains('snack')
        || c.contains('crisp'))               return '🍟';
    if (c.contains('ice cream') || c.contains('frozen'))             return '🍦';
    if (c.contains('noodle')    || c.contains('pasta'))              return '🍜';
    if (c.contains('sauce')     || c.contains('condiment'))          return '🫙';
    if (c.contains('oil')       || c.contains('fat'))                return '🫒';
    if (c.contains('fruit'))                                          return '🍎';
    if (c.contains('vegetable'))                                      return '🥦';
    if (c.contains('meat')      || c.contains('chicken'))            return '🍗';
    if (c.contains('fish')      || c.contains('seafood'))            return '🐟';
    if (c.contains('egg'))                                            return '🥚';
    if (c.contains('nut')       || c.contains('seed'))               return '🥜';
    return '📦';
  }
}