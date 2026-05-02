import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/user_profile.dart';
import '../app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _name   = TextEditingController();
  final _age    = TextEditingController();
  final _weight = TextEditingController();
  final _height = TextEditingController();
  String _goal = 'maintain';
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  void _loadProfile() {
    final p = context.read<UserProvider>().profile;
    _name.text   = p.name;
    _age.text    = p.age.toString();
    _weight.text = p.weight.toString();
    _height.text = p.height.toString();
    setState(() => _goal = p.goal);
  }

  Future<void> _save() async {
    final profile = UserProfile(
      name:  _name.text.isEmpty ? 'User' : _name.text,
      age:   int.tryParse(_age.text) ?? 25,
      weight: double.tryParse(_weight.text) ?? 70,
      height: double.tryParse(_height.text) ?? 170,
      goal: _goal,
      dailyCalorieGoal: 0, // calculated
    );
    await context.read<UserProvider>().save(profile);
    setState(() => _editing = false);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved!'), backgroundColor: AppTheme.healthy),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Profile & Goals'),
        actions: [
          TextButton(
            onPressed: () => _editing ? _save() : setState(() => _editing = true),
            child: Text(_editing ? 'Save' : 'Edit',
                style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Avatar
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.accent],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: Text(
                user.profile.name.isNotEmpty ? user.profile.name[0].toUpperCase() : 'U',
                style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (!_editing) Text(user.profile.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),

          // Stats Card
          if (!_editing)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                _Stat('Age', '${user.profile.age}', 'yrs'),
                const VerticalDivider(width: 32),
                _Stat('Weight', '${user.profile.weight}', 'kg'),
                const VerticalDivider(width: 32),
                _Stat('Height', '${user.profile.height}', 'cm'),
              ]),
            ),

          // Goal Card
          if (!_editing) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary.withOpacity(0.1), AppTheme.accent.withOpacity(0.05)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
              ),
              child: Column(children: [
                const Text('Daily Calorie Goal', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                Text('${user.dailyGoal}',
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700,
                        color: AppTheme.primary, fontFamily: 'Poppins')),
                const Text('kcal/day', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                const SizedBox(height: 8),
                _GoalBadge(user.profile.goal),
              ]),
            ),
          ],

          // Edit Form
          if (_editing) ...[
            _Field('Name', _name, TextInputType.name),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _Field('Age (yrs)', _age, TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _Field('Weight (kg)', _weight, TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _Field('Height (cm)', _height, TextInputType.number)),
            ]),
            const SizedBox(height: 16),
            const Align(alignment: Alignment.centerLeft,
                child: Text('Goal', style: TextStyle(fontWeight: FontWeight.w600))),
            const SizedBox(height: 8),
            ...{
              'loss': '🎯 Weight Loss (-500 kcal)',
              'maintain': '⚖️ Maintain Weight',
              'gain': '💪 Weight Gain (+500 kcal)',
            }.entries.map((e) => RadioListTile<String>(
              value: e.key, groupValue: _goal,
              title: Text(e.value, style: const TextStyle(fontSize: 14)),
              activeColor: AppTheme.primary,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() => _goal = v!),
            )),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity,
                child: ElevatedButton(onPressed: _save, child: const Text('Save Profile'))),
          ],
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value, unit;
  const _Stat(this.label, this.value, this.unit);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
      const SizedBox(height: 3),
      RichText(text: TextSpan(
        children: [
          TextSpan(text: value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary, fontFamily: 'Poppins')),
          TextSpan(text: ' $unit', style: const TextStyle(fontSize: 11,
              color: AppTheme.textMuted, fontFamily: 'Poppins')),
        ],
      )),
    ]),
  );
}

class _GoalBadge extends StatelessWidget {
  final String goal;
  const _GoalBadge(this.goal);

  @override
  Widget build(BuildContext context) {
    final label = goal == 'loss' ? '🎯 Weight Loss' : goal == 'gain' ? '💪 Weight Gain' : '⚖️ Maintain';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }
}

Widget _Field(String label, TextEditingController ctrl, TextInputType type) =>
    TextField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(labelText: label),
    );