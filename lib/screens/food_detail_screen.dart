import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/food_item.dart';
import '../providers/calorie_provider.dart';
import '../services/health_analyzer.dart';
import '../services/tts_service.dart';
import '../app_theme.dart';
import '../widgets/health_score_ring.dart';
import '../widgets/nutrient_bar.dart';
import '../widgets/warning_card.dart';

class FoodDetailScreen extends StatefulWidget {
  final FoodItem food;
  const FoodDetailScreen({super.key, required this.food});

  @override
  State<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends State<FoodDetailScreen> {
  double _quantity = 100;
  String _mealType = 'breakfast';
  bool _speaking = false;
  final _tts = TtsService();

  @override
  void initState() {
    super.initState();
    _quantity = widget.food.servingSize;
  }

  void _speak() async {
    setState(() => _speaking = true);
    final text = HealthAnalyzer.buildTtsSummary(widget.food, _quantity);
    await _tts.speak(text);
    if (mounted) setState(() => _speaking = false);
  }

  @override
  void dispose() { _tts.stop(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final f = widget.food;
    final calories = f.caloriesForQuantity(_quantity);
    final warnings = HealthAnalyzer.analyze(f);
    final additives = HealthAnalyzer.detectAdditives(f.ingredients);
    final healthColor = AppTheme.healthColor(f.healthLabel);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: healthColor,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [healthColor, healthColor.withOpacity(0.7)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Text(f.icon, style: const TextStyle(fontSize: 64)),
                      const SizedBox(height: 8),
                      Text(f.name, textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white,
                              fontSize: 20, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
                      if (f.brand != null)
                        Text(f.brand!, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Health Score + Calories row
                  Row(children: [
                    HealthScoreRing(score: f.healthScore),
                    const SizedBox(width: 20),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${calories.round()}', style: const TextStyle(
                            fontSize: 40, fontWeight: FontWeight.w700,
                            color: AppTheme.primary, fontFamily: 'Poppins')),
                        const Text('calories', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                        const SizedBox(height: 8),
                        Text('for ${_quantity.round()}${f.servingUnit}',
                            style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                        IconButton.filled(
                          onPressed: _speaking ? null : _speak,
                          icon: Icon(_speaking ? Icons.stop : Icons.volume_up_rounded, size: 20),
                          style: IconButton.styleFrom(
                            backgroundColor: AppTheme.primary.withOpacity(0.1),
                            foregroundColor: AppTheme.primary,
                            minimumSize: const Size(38, 38),
                          ),
                        ),
                      ],
                    )),
                  ]),
                  const SizedBox(height: 20),

                  // Quantity Slider
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Text('Quantity', style: TextStyle(fontWeight: FontWeight.w600)),
                          Text('${_quantity.round()} ${f.servingUnit}',
                              style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
                        ]),
                        Slider(
                          value: _quantity,
                          min: 10, max: 500,
                          divisions: 49,
                          activeColor: AppTheme.primary,
                          onChanged: (v) => setState(() => _quantity = v),
                        ),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                          for (final q in [f.servingSize, 100.0, 150.0, 200.0])
                            GestureDetector(
                              onTap: () => setState(() => _quantity = q),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: _quantity == q
                                      ? AppTheme.primary
                                      : AppTheme.primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text('${q.round()}${f.servingUnit}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _quantity == q ? Colors.white : AppTheme.primary,
                                      fontWeight: FontWeight.w500,
                                    )),
                              ),
                            ),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Nutrients
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Nutrition Facts', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 12),
                        NutrientBar(label: 'Protein',  value: (f.protein * _quantity) / 100,  max: 50,  unit: 'g', color: const Color(0xFF42A5F5)),
                        NutrientBar(label: 'Carbs',    value: (f.carbs   * _quantity) / 100,  max: 250, unit: 'g', color: const Color(0xFFFFCA28)),
                        NutrientBar(label: 'Fat',      value: (f.fat     * _quantity) / 100,  max: 65,  unit: 'g', color: const Color(0xFFEF5350)),
                        NutrientBar(label: 'Fiber',    value: (f.fiber   * _quantity) / 100,  max: 25,  unit: 'g', color: const Color(0xFF66BB6A)),
                        NutrientBar(label: 'Sugar',    value: (f.sugar   * _quantity) / 100,  max: 50,  unit: 'g', color: const Color(0xFFFF7043)),
                        NutrientBar(label: 'Sodium',   value: (f.sodium  * _quantity) / 100,  max: 2300,unit: 'mg',color: const Color(0xFFAB47BC)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Warnings
                  if (warnings.isNotEmpty) ...[
                    const Text('⚠️ Health Warnings', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 10),
                    ...warnings.map((w) => WarningCard(warning: w)),
                    const SizedBox(height: 8),
                  ],

                  // Additives
                  if (additives.isNotEmpty) ...[
                    const Text('🧪 Additives Detected', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 10),
                    ...additives.map((a) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (a.risk == 'high' ? AppTheme.danger : AppTheme.moderate).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: (a.risk == 'high' ? AppTheme.danger : AppTheme.moderate).withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (a.risk == 'high' ? AppTheme.danger : AppTheme.moderate).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(a.code,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                  color: a.risk == 'high' ? AppTheme.danger : AppTheme.moderate)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(a.description, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        ])),
                      ]),
                    )),
                    const SizedBox(height: 8),
                  ],

                  // Ingredients
                  if (f.ingredients != null && f.ingredients!.isNotEmpty) ...[
                    const Text('📋 Ingredients', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final ing in f.ingredients!)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.bg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.divider),
                            ),
                            child: Text(ing, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                          ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Meal Selector + Add Button
                  Row(children: [
                    Expanded(child: DropdownButtonFormField<String>(
                      value: _mealType,
                      decoration: const InputDecoration(labelText: 'Meal'),
                      items: const [
                        DropdownMenuItem(value: 'breakfast', child: Text('🌅 Breakfast')),
                        DropdownMenuItem(value: 'lunch',     child: Text('☀️ Lunch')),
                        DropdownMenuItem(value: 'dinner',    child: Text('🌙 Dinner')),
                        DropdownMenuItem(value: 'snack',     child: Text('🍎 Snack')),
                      ],
                      onChanged: (v) => setState(() => _mealType = v ?? 'breakfast'),
                    )),
                  ]),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await context.read<CalorieProvider>().addFood(
                          food: f, quantity: _quantity, mealType: _mealType,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added ${f.name} to $_mealType'),
                              backgroundColor: AppTheme.healthy,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                          Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.add_circle_outline),
                      label: Text('Add to ${_mealType[0].toUpperCase()}${_mealType.substring(1)}'),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}