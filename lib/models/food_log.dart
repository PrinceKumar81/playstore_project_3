import 'food_item.dart';

class FoodLog {
  final String id;
  final String mealType; // 'breakfast' | 'lunch' | 'dinner' | 'snack'
  final FoodItem foodItem;
  final double quantity; // in grams or ml
  final DateTime loggedAt;

  FoodLog({
    required this.id,
    required this.foodItem,
    required this.quantity,
    required this.mealType,
    required this.loggedAt,
  });

  // ── Calculated Macros for this log entry ──────────────────────
  double get calories => (foodItem.caloriesPer100g * quantity) / 100;
  double get protein  => (foodItem.protein         * quantity) / 100;
  double get carbs    => (foodItem.carbs            * quantity) / 100;
  double get fat      => (foodItem.fat              * quantity) / 100;
  double get fiber    => (foodItem.fiber            * quantity) / 100;
  double get sugar    => (foodItem.sugar            * quantity) / 100;
  double get sodium   => (foodItem.sodium           * quantity) / 100;

  // ── Meal label helper ─────────────────────────────────────────
  String get mealLabel {
    switch (mealType) {
      case 'breakfast': return '🌅 Breakfast';
      case 'lunch':     return '☀️ Lunch';
      case 'dinner':    return '🌙 Dinner';
      case 'snack':     return '🍎 Snack';
      default:          return mealType;
    }
  }

  // ── Serialization ─────────────────────────────────────────────
  Map<String, dynamic> toJson() => {
    'id':       id,
    'mealType': mealType,
    'quantity': quantity,
    'loggedAt': loggedAt.toIso8601String(),
    'foodItem': foodItem.toJson(),
  };

  factory FoodLog.fromJson(Map<String, dynamic> json) => FoodLog(
    id:       json['id'] as String,
    mealType: json['mealType'] as String,
    quantity: (json['quantity'] as num).toDouble(),
    loggedAt: DateTime.parse(json['loggedAt'] as String),
    foodItem: FoodItem.fromJson(
        json['foodItem'] as Map<String, dynamic>),
  );

  // ── Equality ──────────────────────────────────────────────────
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is FoodLog && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'FoodLog(id: $id, food: ${foodItem.name}, qty: ${quantity}g, meal: $mealType)';
}