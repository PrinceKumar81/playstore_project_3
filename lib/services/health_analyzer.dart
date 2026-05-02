import '../models/food_item.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class HealthWarning {
  final String title;
  final String message;
  final WarningLevel level;
  const HealthWarning({required this.title, required this.message, required this.level});
}

enum WarningLevel { info, moderate, high }

class Additive {
  final String code, name, type, description, risk;
  const Additive({
    required this.code, required this.name, required this.type,
    required this.description, required this.risk,
  });
}

class HealthAnalyzer {
  static Map<String, Additive>? _additiveMap;

  static Future<void> init() async {
    if (_additiveMap != null) return;
    final raw = await rootBundle.loadString('assets/data/additives.json');
    final data = jsonDecode(raw);
    _additiveMap = {};
    for (final a in (data['harmful'] as List)) {
      _additiveMap![a['code']] = Additive(
        code: a['code'], name: a['name'], type: a['type'],
        description: a['description'], risk: a['risk'],
      );
    }
    for (final a in (data['moderate'] as List)) {
      _additiveMap![a['code']] = Additive(
        code: a['code'], name: a['name'], type: a['type'],
        description: a['description'], risk: a['risk'],
      );
    }
  }

  static List<HealthWarning> analyze(FoodItem food) {
    final warnings = <HealthWarning>[];

    // Sugar
    if (food.sugar > 22.5) {
      warnings.add(const HealthWarning(
        title: '🍬 Very High Sugar',
        message: 'Sugar content exceeds 22.5g/100g. Not good for daily consumption. May cause blood sugar spikes.',
        level: WarningLevel.high,
      ));
    } else if (food.sugar > 12.5) {
      warnings.add(const HealthWarning(
        title: '🍬 High Sugar',
        message: 'Sugar content is above recommended levels (>12.5g/100g). Limit your intake.',
        level: WarningLevel.moderate,
      ));
    }

    // Sodium
    if (food.sodium > 600) {
      warnings.add(const HealthWarning(
        title: '🧂 Very High Sodium',
        message: 'Sodium exceeds 600mg/100g. High salt intake raises blood pressure and cardiovascular risk.',
        level: WarningLevel.high,
      ));
    } else if (food.sodium > 300) {
      warnings.add(const HealthWarning(
        title: '🧂 High Sodium',
        message: 'Sodium is above moderate levels. Monitor daily intake especially if hypertensive.',
        level: WarningLevel.moderate,
      ));
    }

    // Fat
    if (food.fat > 17.5) {
      warnings.add(const HealthWarning(
        title: '🥑 Very High Fat',
        message: 'Fat content exceeds 17.5g/100g. High fat intake may lead to obesity and heart disease.',
        level: WarningLevel.high,
      ));
    } else if (food.fat > 10) {
      warnings.add(const HealthWarning(
        title: '🥑 Moderate Fat',
        message: 'Fat content is moderate (>10g/100g). Consume in controlled portions.',
        level: WarningLevel.moderate,
      ));
    }

    // Low fiber
    if (food.fiber < 1.5 && food.caloriesPer100g > 100) {
      warnings.add(const HealthWarning(
        title: '🌾 Low Fiber',
        message: 'Low dietary fiber content. Pair with fiber-rich foods like vegetables or whole grains.',
        level: WarningLevel.info,
      ));
    }

    return warnings;
  }

  static List<Additive> detectAdditives(List<String>? ingredients) {
    if (ingredients == null || _additiveMap == null) return [];
    final found = <Additive>[];
    final ePattern = RegExp(r'\bE\d{3,4}[a-d]?\b', caseSensitive: false);
    for (final ingredient in ingredients) {
      for (final match in ePattern.allMatches(ingredient)) {
        final code = match.group(0)!.toUpperCase();
        if (_additiveMap!.containsKey(code)) {
          final additive = _additiveMap![code]!;
          if (!found.any((a) => a.code == code)) {
            found.add(additive);
          }
        }
      }
    }
    return found;
  }

  static String buildTtsSummary(FoodItem food, double quantity) {
    final cal = food.caloriesForQuantity(quantity).round();
    final label = food.healthLabel;
    final score = food.healthScore.round();
    return '${food.name} contains $cal calories for ${quantity.round()} grams. '
        'Health score is $score out of 100. Rated $label. '
        '${food.sugar > 12.5 ? "Warning: High sugar content. " : ""}'
        '${food.sodium > 300 ? "Warning: High sodium content. " : ""}';
  }
}