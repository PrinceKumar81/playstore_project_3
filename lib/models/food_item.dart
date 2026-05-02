class FoodItem {
  final String id;
  final String name;
  final String category;
  final double caloriesPer100g;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final double sodium;
  final double servingSize;
  final String servingUnit;
  final String servingLabel;
  final String icon;
  final String? brand;
  final String? imageUrl;
  final String? barcode;
  final List<String>? ingredients;

  const FoodItem({
    required this.id,
    required this.name,
    required this.category,
    required this.caloriesPer100g,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.sugar,
    required this.sodium,
    required this.servingSize,
    required this.servingUnit,
    required this.servingLabel,
    required this.icon,
    this.brand,
    this.imageUrl,
    this.barcode,
    this.ingredients,
  });

  // ── Calculated Helpers ─────────────────────────────────────────
  double caloriesForQuantity(double grams) =>
      (caloriesPer100g * grams) / 100;

  double get healthScore {
    double score = 60;

    // Protein bonus
    if (protein >= 15) score += 15;
    else if (protein >= 10) score += 10;
    else if (protein >= 5) score += 5;

    // Fiber bonus
    if (fiber >= 5) score += 10;
    else if (fiber >= 3) score += 7;
    else if (fiber >= 1.5) score += 3;

    // Sugar penalty
    if (sugar > 22.5)      score -= 20;
    else if (sugar > 12.5) score -= 10;
    else if (sugar <= 5)   score += 5;

    // Sodium penalty
    if (sodium > 600)      score -= 20;
    else if (sodium > 300) score -= 10;
    else if (sodium <= 100) score += 5;

    // Fat penalty
    if (fat > 17.5)      score -= 15;
    else if (fat > 10)   score -= 5;
    else if (fat <= 3)   score += 5;

    // Carbs (moderate)
    if (carbs > 60) score -= 5;

    return score.clamp(0, 100);
  }

  String get healthLabel {
    final s = healthScore;
    if (s >= 80) return 'Healthy';
    if (s >= 50) return 'Moderate';
    return 'Avoid';
  }

  // ── Serialization ──────────────────────────────────────────────
  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
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

  Map<String, dynamic> toJson() => {
    'id':              id,
    'name':            name,
    'category':        category,
    'caloriesPer100g': caloriesPer100g,
    'protein':         protein,
    'carbs':           carbs,
    'fat':             fat,
    'fiber':           fiber,
    'sugar':           sugar,
    'sodium':          sodium,
    'servingSize':     servingSize,
    'servingUnit':     servingUnit,
    'servingLabel':    servingLabel,
    'icon':            icon,
    'brand':           brand,
    'imageUrl':        imageUrl,
    'barcode':         barcode,
    'ingredients':     ingredients,
  };

  // ── Equality ───────────────────────────────────────────────────
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is FoodItem && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'FoodItem(id: $id, name: $name, cal: $caloriesPer100g)';
}