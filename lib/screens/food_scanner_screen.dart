import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import '../services/open_food_facts_service.dart';
import '../services/usda_food_service.dart';
import '../services/indian_food_service.dart';
import '../models/food_item.dart';
import '../app_theme.dart';
import '../providers/calorie_provider.dart';
import 'food_detail_screen.dart';
import 'search_screen.dart';

// ═══════════════════════════════════════════════════════════════
// Public enum
enum ScannerMode { ai, barcode, manual }

// Internal state
enum ScanState { init, scanning, loading, detected, result, error }

// ═══════════════════════════════════════════════════════════════
class FoodScannerScreen extends StatefulWidget {
  final ScannerMode initialMode;
  const FoodScannerScreen({super.key, this.initialMode = ScannerMode.ai});

  @override
  State<FoodScannerScreen> createState() => _FoodScannerScreenState();
}

class _FoodScannerScreenState extends State<FoodScannerScreen>
    with TickerProviderStateMixin {
  // ── Camera ──────────────────────────────────────────────────
  CameraController? cam;
  List<CameraDescription> cameras = [];
  bool torchOn = false;

  // ── ML Kit ──────────────────────────────────────────────────
  // ✅ OPTIMIZED: Specific barcode formats instead of all
  final barcodeScanner = BarcodeScanner(formats: [
    BarcodeFormat.ean13,
    BarcodeFormat.ean8,
    BarcodeFormat.upca,
    BarcodeFormat.upce,
    BarcodeFormat.code128,
    BarcodeFormat.qrCode,
  ]);

  // ✅ OPTIMIZED: Increased confidence threshold from 0.65 to 0.75
  final imageLabeler = ImageLabeler(
    options: ImageLabelerOptions(confidenceThreshold: 0.75),
  );

  // ── State ───────────────────────────────────────────────────
  ScanState state = ScanState.init;
  ScannerMode mode = ScannerMode.ai;
  FoodItem? result;
  String detectedLabel = '';
  double confidence = 0;
  String errorMsg = '';
  bool frameProcessing = false;
  Timer? debounce;

  // ✅ NEW: Frame skipping optimization
  int _frameSkipCounter = 0;
  DateTime? _lastDetectionTime;

  // ── Animations ──────────────────────────────────────────────
  late AnimationController pulseCtrl;
  late AnimationController slideCtrl;
  late AnimationController fadeCtrl;
  late Animation<double> pulseAnim;
  late Animation<Offset> slideAnim;
  late Animation<double> fadeAnim;

  @override
  void initState() {
    super.initState();
    mode = widget.initialMode;
    _setupAnimations();
    _initCamera();
  }

  void _setupAnimations() {
    pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );

    fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    pulseAnim = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: pulseCtrl, curve: Curves.easeInOut),
    );

    slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: slideCtrl, curve: Curves.easeOutCubic));

    fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: fadeCtrl, curve: Curves.easeIn),
    );
  }

  // ── Camera Init ─────────────────────────────────────────────
  Future<void> _initCamera() async {
    if (!mounted) return;
    setState(() => state = ScanState.init);

    try {
      cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          state = ScanState.error;
          errorMsg = 'No camera available on this device';
        });
        return;
      }

      // ✅ OPTIMIZED: Changed from ResolutionPreset.high to medium for faster processing
      cam = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await cam!.initialize();
      if (!mounted) return;

      setState(() => state = ScanState.scanning);
      fadeCtrl.forward();

      if (mode != ScannerMode.manual) {
        _startStream();
      }
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        state = ScanState.error;
        errorMsg = e.code == 'CameraAccessDenied'
            ? 'Camera permission denied. Enable in Settings.'
            : 'Camera error: ${e.description}';
      });
    }
  }

  // ── Image Stream ────────────────────────────────────────────
  void _startStream() {
    cam?.startImageStream((CameraImage image) {
      if (frameProcessing || state != ScanState.scanning) return;

      // ✅ OPTIMIZED: Skip every 2 out of 3 frames (67% less processing)
      _frameSkipCounter++;
      if (_frameSkipCounter < 3) return;
      _frameSkipCounter = 0;

      // ✅ OPTIMIZED: Reduced debounce from 400ms to 250ms
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 250), () async {
        if (frameProcessing || !mounted || state != ScanState.scanning) return;

        // ✅ NEW: Rate limiting - prevent scanning same thing repeatedly
        final now = DateTime.now();
        if (_lastDetectionTime != null &&
            now.difference(_lastDetectionTime!).inSeconds < 2) {
          return;
        }

        frameProcessing = true;

        try {
          final inputImage = _buildInputImage(image);
          if (inputImage == null) {
            frameProcessing = false;
            return;
          }

          // ✅ OPTIMIZED: Mode-specific processing (no longer runs both)
          if (mode == ScannerMode.barcode) {
            // ONLY barcode scan
            final barcodes = await barcodeScanner.processImage(inputImage);
            if (barcodes.isNotEmpty) {
              final code = barcodes.first.rawValue;
              if (code != null && code.isNotEmpty) {
                _lastDetectionTime = now;
                frameProcessing = false;
                _handleBarcode(code);
                return;
              }
            }
          } else if (mode == ScannerMode.ai) {
            // ONLY AI label
            final labels = await imageLabeler.processImage(inputImage);
            final foodLabels =
            labels.where((l) => _isFoodLabel(l.label)).toList();

            // ✅ OPTIMIZED: Increased threshold from 0.70 to 0.78
            if (foodLabels.isNotEmpty && foodLabels.first.confidence >= 0.78) {
              _lastDetectionTime = now;
              frameProcessing = false;
              _handleAILabel(foodLabels.first.label, foodLabels.first.confidence);
              return;
            }
          }
        } catch (_) {
          // Silently skip bad frames
        }

        frameProcessing = false;
      });
    });
  }

  // ── Build InputImage ────────────────────────────────────────
  InputImage? _buildInputImage(CameraImage image) {
    if (cam == null) return null;

    final sensorOrientation = cameras.first.sensorOrientation;
    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    if (Platform.isAndroid && format != InputImageFormat.nv21) return null;
    if (Platform.isIOS && format != InputImageFormat.bgra8888) return null;

    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  // ── Barcode Handler ─────────────────────────────────────────
  Future<void> _handleBarcode(String code) async {
    if (state != ScanState.scanning) return;

    await cam?.stopImageStream();
    if (!mounted) return;

    setState(() {
      state = ScanState.loading;
      detectedLabel = code;
    });

    // Try Open Food Facts first (best for EAN/UPC barcodes)
    final food = await OpenFoodFactsService.fetchByBarcode(code);
    if (!mounted) return;

    if (food != null) {
      _showResult(food);
      return;
    }

    // Fallback: try USDA by barcode (GTIN/UPC lookup via search)
    final usdaResults = await USDAFoodService.searchByName(code, pageSize: 3);
    if (!mounted) return;

    if (usdaResults.isNotEmpty) {
      _showResult(usdaResults.first);
      return;
    }

    setState(() {
      state = ScanState.error;
      errorMsg =
      'Product not found for barcode "$code". Try manual search.';
    });
  }

  // ── AI Label Handler ────────────────────────────────────────
  Future<void> _handleAILabel(String label, double confidence) async {
    if (state != ScanState.scanning) return;

    await cam?.stopImageStream();
    if (!mounted) return;

    // Show detected badge while we look up nutrition
    setState(() {
      state = ScanState.detected;
      detectedLabel = label;
      this.confidence = confidence;
    });

    // Small delay so user can see the detected badge
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    setState(() => state = ScanState.loading);

    // Step 1: USDA FoodData Central
    final usdaResults = await USDAFoodService.searchByName(
      label,
      pageSize: 5,
      pageNumber: 1,
    );
    if (!mounted) return;

    if (usdaResults.isNotEmpty) {
      _showResult(usdaResults.first);
      return;
    }

    // Step 2: Offline Indian food dataset
    final indianResults = await IndianFoodService.search(label);
    if (!mounted) return;

    if (indianResults.isNotEmpty) {
      _showResult(indianResults.first);
      return;
    }

    // Step 3: Try Open Food Facts text search as last resort
    final offResults = await OpenFoodFactsService.searchByName(label);
    if (!mounted) return;

    if (offResults.isNotEmpty) {
      _showResult(offResults.first);
      return;
    }

    // Step 4: Nothing found
    setState(() {
      state = ScanState.error;
      errorMsg =
      'No nutrition info found for "$label". Try searching manually or scan the barcode.';
    });
  }

  // ── Show Result ─────────────────────────────────────────────
  void _showResult(FoodItem food) {
    if (!mounted) return;
    setState(() {
      result = food;
      state = ScanState.result;
    });
    slideCtrl.forward(from: 0);
  }

  // ── Scan Again ──────────────────────────────────────────────
  Future<void> _scanAgain() async {
    await slideCtrl.reverse();
    if (!mounted) return;

    result = null;
    detectedLabel = '';
    _lastDetectionTime = null; // ✅ Reset rate limiter
    _frameSkipCounter = 0;     // ✅ Reset frame counter

    setState(() => state = ScanState.scanning);
    _startStream();
  }

  // ── Torch ───────────────────────────────────────────────────
  Future<void> _toggleTorch() async {
    try {
      torchOn = !torchOn;
      await cam?.setFlashMode(torchOn ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  // ── Switch Mode ─────────────────────────────────────────────
  Future<void> _switchMode(ScannerMode newMode) async {
    if (mode == newMode) return;

    await cam?.stopImageStream();
    debounce?.cancel();
    frameProcessing = false;
    result = null;
    _lastDetectionTime = null; // ✅ Reset rate limiter
    _frameSkipCounter = 0;     // ✅ Reset frame counter

    setState(() {
      mode = newMode;
      state = ScanState.scanning;
    });

    if (newMode != ScannerMode.manual) {
      _startStream();
    }
  }

  // ── Food Label Filter ───────────────────────────────────────
  bool _isFoodLabel(String label) {
    const foodKeywords = [
      'food', 'fruit', 'vegetable', 'meat', 'bread', 'rice', 'pizza', 'burger',
      'salad', 'soup', 'cake', 'cookie', 'drink', 'juice', 'coffee', 'tea',
      'cheese', 'egg', 'chicken', 'fish', 'pasta', 'noodle', 'curry', 'roti',
      'dal', 'biryani', 'snack', 'dessert', 'sandwich', 'wrap', 'bowl', 'plate',
      'meal', 'cuisine', 'dish', 'apple', 'banana', 'orange', 'mango', 'tomato',
      'potato', 'onion', 'cereal', 'yogurt', 'milk', 'chocolate', 'candy',
      'taco', 'sushi', 'paneer', 'samosa', 'idli', 'dosa',
    ];
    final l = label.toLowerCase();
    return foodKeywords.any((k) => l.contains(k));
  }

  // ── Current Meal Type ───────────────────────────────────────
  String get _currentMealType {
    final h = DateTime.now().hour;
    if (h < 11) return 'breakfast';
    if (h < 15) return 'lunch';
    if (h < 19) return 'dinner';
    return 'snack';
  }

  @override
  void dispose() {
    debounce?.cancel();
    pulseCtrl.dispose();
    slideCtrl.dispose();
    fadeCtrl.dispose();
    barcodeScanner.close();
    imageLabeler.close();
    cam?.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          if (cam != null && cam!.value.isInitialized)
            FadeTransition(
              opacity: fadeAnim,
              child: CameraPreview(cam!),
            ),

          // Background fallback
          if (cam == null || !cam!.value.isInitialized)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0D1F1E), Color(0xFF000000)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),

          // Top vignette
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 180,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.80),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // Bottom vignette
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 220,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.70),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // Top bar + mode tabs
          SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTopBar(),
                const SizedBox(height: 12),
                _buildModeTabs(),
              ],
            ),
          ),

          // Scanning overlay
          if (state == ScanState.scanning && mode != ScannerMode.manual)
            Center(
              child: mode == ScannerMode.barcode
                  ? BarcodeOverlay(pulseAnim: pulseAnim)
                  : AiOverlay(pulseAnim: pulseAnim),
            ),

          // Scan hint
          if (state == ScanState.scanning && mode != ScannerMode.manual)
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: Center(
                child: HintPill(
                  text: mode == ScannerMode.barcode
                      ? 'Point at barcode'
                      : 'Point at any food item',
                ),
              ),
            ),

          // Manual search panel
          if (mode == ScannerMode.manual)
            Positioned.fill(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
                  child: const ManualSearchPanel(),
                ),
              ),
            ),

          // Init loader
          if (state == ScanState.init) const Center(child: InitLoader()),

          // Loading
          if (state == ScanState.loading)
            Center(
              child: LoadingCard(
                label: detectedLabel,
                isBarcode: mode == ScannerMode.barcode,
              ),
            ),

          // Detected badge
          if (state == ScanState.detected)
            Center(
              child: DetectedBadge(
                label: detectedLabel,
                confidence: confidence,
              ),
            ),

          // Error card
          if (state == ScanState.error)
            Center(
              child: ErrorCard(
                message: errorMsg,
                onRetry: _scanAgain,
                onSearch: () => _switchMode(ScannerMode.manual),
              ),
            ),

          // Result bottom sheet
          if (state == ScanState.result && result != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SlideTransition(
                position: slideAnim,
                child: ResultCard(
                  food: result!,
                  mode: mode,
                  detectedLabel: detectedLabel,
                  onScanAgain: _scanAgain,
                  onViewDetails: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FoodDetailScreen(food: result!),
                      ),
                    );
                  },
                  onSave: () async {
                    await context.read<CalorieProvider>().addFood(
                      food: result!,
                      quantity: result!.servingSize,
                      mealType: _currentMealType,
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('${result!.name} added to $_currentMealType'),
                      backgroundColor: AppTheme.healthy,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ));
                    _scanAgain();
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Top Bar ─────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          CircleBtn(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: const Text(
              'Food Scanner',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins',
              ),
            ),
          ),
          const Spacer(),
          if (mode != ScannerMode.manual)
            CircleBtn(
              icon: torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: torchOn ? const Color(0xFFFFD740) : Colors.white,
              onTap: _toggleTorch,
            )
          else
            const SizedBox(width: 42),
        ],
      ),
    );
  }

  // ── Mode Tabs ───────────────────────────────────────────────
  Widget _buildModeTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 46,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            ModeTab(
              emoji: '🤖',
              label: 'AI Scan',
              active: mode == ScannerMode.ai,
              activeColor: AppTheme.primary,
              onTap: () => _switchMode(ScannerMode.ai),
            ),
            ModeTab(
              emoji: '📦',
              label: 'Barcode',
              active: mode == ScannerMode.barcode,
              activeColor: const Color(0xFF7C4DFF),
              onTap: () => _switchMode(ScannerMode.barcode),
            ),
            ModeTab(
              emoji: '🔍',
              label: 'Search',
              active: mode == ScannerMode.manual,
              activeColor: const Color(0xFF0288D1),
              onTap: () => _switchMode(ScannerMode.manual),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// OVERLAYS
// ═══════════════════════════════════════════════════════════════
class AiOverlay extends StatelessWidget {
  final Animation<double> pulseAnim;
  const AiOverlay({super.key, required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: pulseAnim,
      child: SizedBox(
        width: 270,
        height: 270,
        child: Stack(children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppTheme.primary.withOpacity(0.25),
                width: 1.2,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.primary, width: 2),
              ),
              child: const Stack(children: [
                CornerAccents(color: AppTheme.primary),
                ScanLineAnimator(color: AppTheme.primary),
              ]),
            ),
          ),
          Center(
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
              ),
              child: const Center(
                child: Text('🤖', style: TextStyle(fontSize: 36)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class BarcodeOverlay extends StatelessWidget {
  final Animation<double> pulseAnim;
  const BarcodeOverlay({super.key, required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF7C4DFF);
    return ScaleTransition(
      scale: pulseAnim,
      child: SizedBox(
        width: 300,
        height: 180,
        child: Stack(children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.3), width: 1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color, width: 2),
              ),
              child: const Stack(children: [
                CornerAccents(color: color),
                ScanLineAnimator(color: color),
              ]),
            ),
          ),
          Center(
            child: Icon(Icons.qr_code_rounded,
                color: color.withOpacity(0.12), size: 70),
          ),
        ]),
      ),
    );
  }
}

// ── Corner Accents ──────────────────────────────────────────────
class CornerAccents extends StatelessWidget {
  final Color color;
  const CornerAccents({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      for (final config in [
        {'top': true, 'left': true},
        {'top': true, 'left': false},
        {'top': false, 'left': true},
        {'top': false, 'left': false},
      ])
        Align(
          alignment: Alignment(
            (config['left'] as bool) ? -1.0 : 1.0,
            (config['top'] as bool) ? -1.0 : 1.0,
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              width: 22,
              height: 22,
              child: CustomPaint(
                painter: CornerPainter(
                  color: color,
                  isLeft: config['left'] as bool,
                  isTop: config['top'] as bool,
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}

class CornerPainter extends CustomPainter {
  final Color color;
  final bool isLeft, isTop;
  const CornerPainter({
    required this.color,
    required this.isLeft,
    required this.isTop,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final x = isLeft ? 0.0 : size.width;
    final y = isTop ? 0.0 : size.height;

    canvas.drawLine(
      Offset(x, y),
      Offset(isLeft ? size.width * 0.65 : size.width * 0.35, y),
      p,
    );
    canvas.drawLine(
      Offset(x, y),
      Offset(x, isTop ? size.height * 0.65 : size.height * 0.35),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Animated Scan Line ──────────────────────────────────────────
class ScanLineAnimator extends StatefulWidget {
  final Color color;
  const ScanLineAnimator({super.key, required this.color});

  @override
  State<ScanLineAnimator> createState() => _ScanLineAnimatorState();
}

class _ScanLineAnimatorState extends State<ScanLineAnimator>
    with SingleTickerProviderStateMixin {
  late AnimationController ctrl;
  late Animation<double> anim;

  @override
  void initState() {
    super.initState();
    ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    anim = Tween<double>(begin: 0.05, end: 0.92).animate(
      CurvedAnimation(parent: ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Positioned(
        top: 0,
        bottom: 0,
        left: 0,
        right: 0,
        child: Align(
          alignment: Alignment(0, anim.value * 2 - 1),
          child: Container(
            height: 2.5,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent,
                widget.color.withOpacity(0.9),
                widget.color,
                widget.color.withOpacity(0.9),
                Colors.transparent,
              ]),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(0.6),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// STATE CARDS
// ═══════════════════════════════════════════════════════════════
class InitLoader extends StatelessWidget {
  const InitLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              color: AppTheme.primary,
              strokeWidth: 3,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Initializing camera...',
            style: TextStyle(color: Colors.white70, fontSize: 14)),
      ],
    );
  }
}

class LoadingCard extends StatelessWidget {
  final String label;
  final bool isBarcode;
  const LoadingCard({super.key, required this.label, required this.isBarcode});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.20),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: AppTheme.primary,
              strokeWidth: 3,
              backgroundColor: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isBarcode
                ? 'Fetching product info...'
                : 'Analyzing ${label.isNotEmpty ? label : 'food'}...',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Looking up nutrition database',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class DetectedBadge extends StatelessWidget {
  final String label;
  final double confidence;
  const DetectedBadge(
      {super.key, required this.label, required this.confidence});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withOpacity(0.95),
            const Color(0xFF26C6DA).withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Food Detected!',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins',
              )),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('${(confidence * 100).round()}% confident',
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry, onSearch;
  const ErrorCard({
    super.key,
    required this.message,
    required this.onRetry,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.danger.withOpacity(0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppTheme.danger.withOpacity(0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
                child: Text('⚠️', style: TextStyle(fontSize: 32))),
          ),
          const SizedBox(height: 14),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 14, height: 1.5)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Try Again'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onSearch,
                icon: const Icon(Icons.search_rounded, size: 16),
                label: const Text('Search'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// RESULT CARD
// ═══════════════════════════════════════════════════════════════
class ResultCard extends StatelessWidget {
  final FoodItem food;
  final ScannerMode mode;
  final String detectedLabel;
  final VoidCallback onScanAgain, onViewDetails, onSave;

  const ResultCard({
    super.key,
    required this.food,
    required this.mode,
    required this.detectedLabel,
    required this.onScanAgain,
    required this.onViewDetails,
    required this.onSave,
  });

  Color get hColor => AppTheme.healthColor(food.healthLabel);

  @override
  Widget build(BuildContext context) {
    final cal = food.caloriesForQuantity(food.servingSize).round();
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F1923),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 14, bottom: 4),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: hColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                      border:
                      Border.all(color: hColor.withOpacity(0.25)),
                    ),
                    child: Center(
                        child: Text(food.icon,
                            style: const TextStyle(fontSize: 32))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(food.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Poppins',
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        if (food.brand != null) ...[
                          const SizedBox(height: 2),
                          Text(food.brand!,
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 12)),
                        ],
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, children: [
                          Badge(text: food.healthLabel, color: hColor),
                          Badge(
                            text: mode == ScannerMode.barcode
                                ? 'Barcode'
                                : mode == ScannerMode.ai
                                ? 'AI'
                                : 'Search',
                            color: mode == ScannerMode.barcode
                                ? const Color(0xFF7C4DFF)
                                : AppTheme.primary,
                            outlined: true,
                          ),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  CalCircle(cal: cal, color: hColor),
                ]),
                const SizedBox(height: 18),

                // Nutrition strip
                NutritionStrip(food: food),
                const SizedBox(height: 14),

                // Serving info
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(children: [
                    const Icon(Icons.scale_rounded,
                        color: Colors.white38, size: 15),
                    const SizedBox(width: 8),
                    Text(
                      'Per ${food.servingLabel} • ${food.caloriesPer100g.round()} kcal / 100g',
                      style:
                      const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ]),
                ),
                const SizedBox(height: 18),

                // Action buttons
                Row(children: [
                  ActionBtn(
                    icon: Icons.refresh_rounded,
                    label: 'Scan Again',
                    outlined: true,
                    onTap: onScanAgain,
                  ),
                  const SizedBox(width: 8),
                  ActionBtn(
                    icon: Icons.info_outline_rounded,
                    label: 'Details',
                    outlined: true,
                    color: AppTheme.primary,
                    onTap: onViewDetails,
                  ),
                  const SizedBox(width: 8),
                  ActionBtn(
                    icon: Icons.add_circle_outline_rounded,
                    label: 'Save',
                    onTap: onSave,
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// MANUAL SEARCH PANEL
// ═══════════════════════════════════════════════════════════════
class ManualSearchPanel extends StatelessWidget {
  const ManualSearchPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1923).withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Search Food',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins',
                )),
            const SizedBox(height: 6),
            const Text('Search Indian foods or packaged products',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SearchScreen()));
                },
                icon: const Icon(Icons.search_rounded),
                label: const Text('Open Food Search'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                          const SearchScreen(indiaOnly: true)));
                },
                icon: const Text('🇮🇳', style: TextStyle(fontSize: 16)),
                label: const Text('Indian Foods Only'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════
// SMALL REUSABLE WIDGETS
// ═══════════════════════════════════════════════════════════════
class CircleBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const CircleBtn(
      {super.key, required this.icon, required this.onTap, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

class ModeTab extends StatelessWidget {
  final String emoji, label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;
  const ModeTab({
    super.key,
    required this.emoji,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color:
            active ? activeColor.withOpacity(0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: active
                ? Border.all(color: activeColor.withOpacity(0.4))
                : null,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            Text(label,
                style: TextStyle(
                  color: active ? activeColor : Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                )),
          ]),
        ),
      ),
    );
  }
}

class HintPill extends StatelessWidget {
  final String text;
  const HintPill({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          )),
    );
  }
}

class Badge extends StatelessWidget {
  final String text;
  final Color color;
  final bool outlined;
  const Badge(
      {super.key,
        required this.text,
        required this.color,
        this.outlined = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: outlined ? color.withOpacity(0.5) : Colors.transparent,
        ),
      ),
      child: Text(text,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          )),
    );
  }
}

class CalCircle extends StatelessWidget {
  final int cal;
  final Color color;
  const CalCircle({super.key, required this.cal, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$cal',
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins',
              )),
          Text('kcal',
              style: TextStyle(color: color.withOpacity(0.7), fontSize: 9)),
        ],
      ),
    );
  }
}

class NutritionStrip extends StatelessWidget {
  final FoodItem food;
  const NutritionStrip({super.key, required this.food});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      NutChip('P', '${food.protein.toStringAsFixed(1)}g',
          const Color(0xFF42A5F5)),
      const SizedBox(width: 8),
      NutChip(
          'C', '${food.carbs.toStringAsFixed(1)}g', const Color(0xFFFFCA28)),
      const SizedBox(width: 8),
      NutChip('F', '${food.fat.toStringAsFixed(1)}g', const Color(0xFFEF5350)),
      const SizedBox(width: 8),
      NutChip('Na', '${food.sodium.round()}mg', const Color(0xFFAB47BC)),
    ]);
  }
}

class NutChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const NutChip(this.label, this.value, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(children: [
          Text(label,
              style: TextStyle(
                  color: color.withOpacity(0.7),
                  fontSize: 10)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              )),
        ]),
      ),
    );
  }
}

class ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool outlined;
  final Color? color;
  final VoidCallback onTap;
  const ActionBtn({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.outlined = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primary;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: outlined ? Colors.transparent : c,
            borderRadius: BorderRadius.circular(12),
            border: outlined ? Border.all(color: Colors.white24) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 18,
                  color: outlined ? Colors.white60 : Colors.white),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(
                    color: outlined ? Colors.white60 : Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}