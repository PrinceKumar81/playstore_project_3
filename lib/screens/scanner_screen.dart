import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/open_food_facts_service.dart';
import '../app_theme.dart';
import 'food_detail_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _ctrl = MobileScannerController();
  bool _scanning = true;
  bool _loading = false;
  bool _torchOn = false; // ✅ manual torch state tracking

  Future<void> _handleBarcode(String code) async {
    if (!_scanning) return;
    _scanning = false;
    setState(() => _loading = true);
    await _ctrl.stop();

    final food = await OpenFoodFactsService.fetchByBarcode(code);
    if (!mounted) return;
    setState(() => _loading = false);

    if (food != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => FoodDetailScreen(food: food)),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Not Found'),
          content: Text('No product found for barcode:\n$code'),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                setState(() => _scanning = true);
                await _ctrl.start();
              },
              child: const Text('Try Again'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    }
  }

  // ✅ Fixed: use ctrl.toggleTorch() and track state manually
  Future<void> _toggleTorch() async {
    await _ctrl.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Scan Barcode',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // ✅ Fixed: no torchState ValueListenable, use local _torchOn bool
          IconButton(
            icon: Icon(
              _torchOn ? Icons.flash_on : Icons.flash_off,
              color: _torchOn ? Colors.yellow : Colors.white,
            ),
            onPressed: _toggleTorch,
            tooltip: _torchOn ? 'Turn off torch' : 'Turn on torch',
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Scanner ─────────────────────────────────────────────
          MobileScanner(
            controller: _ctrl,
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final code = barcodes.first.rawValue;
                if (code != null) _handleBarcode(code);
              }
            },
          ),

          // ── Scan Overlay Frame ───────────────────────────────────
          Center(
            child: Container(
              width: 260,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppTheme.primary,
                  width: 2.5,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  for (final pos in [
                    Alignment.topLeft,
                    Alignment.topRight,
                    Alignment.bottomLeft,
                    Alignment.bottomRight,
                  ])
                    Align(alignment: pos, child: _Corner(pos)),
                ],
              ),
            ),
          ),

          // ── Animated Scan Line ───────────────────────────────────
          const Center(child: _ScanLine()),

          // ── Bottom Label ─────────────────────────────────────────
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Column(
              children: [
                if (_loading)
                  const CircularProgressIndicator(color: AppTheme.primary),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _loading
                        ? 'Looking up product...'
                        : 'Point at a barcode to scan',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Corner Painter ─────────────────────────────────────────────────────────────
class _Corner extends StatelessWidget {
  final Alignment alignment;
  const _Corner(this.alignment);

  @override
  Widget build(BuildContext context) {
    final isLeft =
        alignment == Alignment.topLeft || alignment == Alignment.bottomLeft;
    final isTop =
        alignment == Alignment.topLeft || alignment == Alignment.topRight;
    return Padding(
      padding: const EdgeInsets.all(6),
      child: SizedBox(
        width: 20,
        height: 20,
        child: CustomPaint(
          painter: _CornerPainter(isLeft: isLeft, isTop: isTop),
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final bool isLeft, isTop;
  _CornerPainter({required this.isLeft, required this.isTop});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppTheme.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final x = isLeft ? 0.0 : size.width;
    final y = isTop ? 0.0 : size.height;
    canvas.drawLine(Offset(x, y), Offset(isLeft ? size.width : 0, y), p);
    canvas.drawLine(Offset(x, y), Offset(x, isTop ? size.height : 0), p);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Animated Scan Line ─────────────────────────────────────────────────────────
class _ScanLine extends StatefulWidget {
  const _ScanLine();

  @override
  State<_ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<_ScanLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: -80, end: 80).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: Container(
          width: 240,
          height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                AppTheme.primary.withOpacity(0.8),
                Colors.transparent,
              ],
            ),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }
}