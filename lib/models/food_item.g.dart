// food_item.g.dart
// Manual serialization helpers — no build_runner needed.
// This mirrors what json_serializable would generate.

import 'food_item.dart';

FoodItem foodItemFromJson(Map<String, dynamic> json) => FoodItem(
  id:              json['id'] as String,
  name:            json['name'] as String,
  category:        (json['category'] as String?) ?? '',
  caloriesPer100g: (json['caloriesPer100g'] as num).toDouble(),
  protein:         (json['protein'] as num).toDouble(),
  carbs:           (json['carbs'] as num).toDouble(),
  fat:             (json['fat'] as num).toDouble(),
  fiber:           (json['fiber'] as num).toDouble(),
  sugar:           (json['sugar'] as num).toDouble(),
  sodium:          (json['sodium'] as num).toDouble(),
  servingSize:     (json['servingSize'] as num).toDouble(),
  servingUnit:     (json['servingUnit'] as String?) ?? 'g',
  servingLabel:    (json['servingLabel'] as String?) ?? '100g',
  icon:            (json['icon'] as String?) ?? '🍽️',
  brand:           json['brand'] as String?,
  imageUrl:        json['imageUrl'] as String?,
  barcode:         json['barcode'] as String?,
  ingredients:     (json['ingredients'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
);

Map<String, dynamic> foodItemToJson(FoodItem item) => {
  'id':              item.id,
  'name':            item.name,
  'category':        item.category,
  'caloriesPer100g': item.caloriesPer100g,
  'protein':         item.protein,
  'carbs':           item.carbs,
  'fat':             item.fat,
  'fiber':           item.fiber,
  'sugar':           item.sugar,
  'sodium':          item.sodium,
  'servingSize':     item.servingSize,
  'servingUnit':     item.servingUnit,
  'servingLabel':    item.servingLabel,
  'icon':            item.icon,
  'brand':           item.brand,
  'imageUrl':        item.imageUrl,
  'barcode':         item.barcode,
  'ingredients':     item.ingredients,
};