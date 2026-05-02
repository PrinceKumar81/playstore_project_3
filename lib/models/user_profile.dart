import 'package:hive/hive.dart';

enum GoalType { weightLoss, weightGain, maintain }

class UserProfile {
  final String name;
  final int age;
  final double weight;
  final double height;
  final String goal;
  final int dailyCalorieGoal;

  UserProfile({
    required this.name,
    required this.age,
    required this.weight,
    required this.height,
    required this.goal,
    required this.dailyCalorieGoal,
  });

  factory UserProfile.defaultProfile() => UserProfile(
    name: 'User',
    age: 25,
    weight: 70,
    height: 170,
    goal: 'maintain',
    dailyCalorieGoal: 2000,
  );

  int get calculatedGoal {
    // Mifflin-St Jeor BMR
    double bmr = 10 * weight + 6.25 * height - 5 * age + 5;
    double tdee = bmr * 1.375; // Light activity
    if (goal == 'loss') return (tdee - 500).round();
    if (goal == 'gain') return (tdee + 500).round();
    return tdee.round();
  }

  Map<String, dynamic> toJson() => {
    'name': name, 'age': age, 'weight': weight,
    'height': height, 'goal': goal, 'dailyCalorieGoal': dailyCalorieGoal,
  };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    name: j['name'], age: j['age'], weight: (j['weight'] as num).toDouble(),
    height: (j['height'] as num).toDouble(), goal: j['goal'],
    dailyCalorieGoal: j['dailyCalorieGoal'],
  );

  UserProfile copyWith({
    String? name, int? age, double? weight, double? height,
    String? goal, int? dailyCalorieGoal,
  }) => UserProfile(
    name: name ?? this.name, age: age ?? this.age,
    weight: weight ?? this.weight, height: height ?? this.height,
    goal: goal ?? this.goal, dailyCalorieGoal: dailyCalorieGoal ?? this.dailyCalorieGoal,
  );
}