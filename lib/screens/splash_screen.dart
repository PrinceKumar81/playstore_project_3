import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/calorie_provider.dart';
import '../providers/user_provider.dart';
import '../services/health_analyzer.dart';
import '../app_theme.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoCtrl, _textCtrl;
  late Animation<double> _logoScale, _logoFade, _textFade, _textSlide;

  @override
  void initState() {
    super.initState();
    _logoCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _textCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

    _logoScale = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoFade  = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.easeIn));
    _textFade  = Tween<double>(begin: 0, end: 1).animate(_textCtrl);
    _textSlide = Tween<double>(begin: 20, end: 0)
        .animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));

    _startSequence();
  }

  Future<void> _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 600));
    _textCtrl.forward();

    // Init services
    await HealthAnalyzer.init();
    await context.read<UserProvider>().load();
    await context.read<CalorieProvider>().loadToday();

    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, a, __) => const HomeScreen(),
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  void dispose() {
    _logoCtrl.dispose(); _textCtrl.dispose(); super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _logoCtrl,
              builder: (_, __) => FadeTransition(
                opacity: _logoFade,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: Container(
                    width: 110, height: 110,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: const Center(
                      child: Text('🥗', style: TextStyle(fontSize: 56)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            AnimatedBuilder(
              animation: _textCtrl,
              builder: (_, __) => FadeTransition(
                opacity: _textFade,
                child: Transform.translate(
                  offset: Offset(0, _textSlide.value),
                  child: Column(children: [
                    const Text(
                      'Smart Calorie',
                      style: TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w700,
                        color: Colors.white, fontFamily: 'Poppins', letterSpacing: -0.5,
                      ),
                    ),
                    const Text(
                      '& Health Checker',
                      style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w400,
                        color: Colors.white70, fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '🇮🇳 Indian Food Included',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 60),
            const SizedBox(
              width: 28, height: 28,
              child: CircularProgressIndicator(
                color: Colors.white54, strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}