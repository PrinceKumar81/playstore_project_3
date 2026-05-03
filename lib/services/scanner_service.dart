import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:flutter/foundation.dart';

enum ScanMode { barcode, aiLabel, idle }

class ScanResult {
  final ScanMode mode;
  final String? barcode;
  final String? label;
  final double? confidence;
  ScanResult({required this.mode, this.barcode, this.label, this.confidence});
}

class ScannerService {
  CameraController? _cameraCtrl;
  final _barcodeScanner = BarcodeScanner();
  final _imageLabeler   = ImageLabeler(
    options: ImageLabelerOptions(confidenceThreshold: 0.65),
  );

  bool _isProcessing = false;
  bool _disposed = false;

  // ── Camera Init ───────────────────────────────────────────────
  Future<CameraController?> initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return null;
      _cameraCtrl = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await _cameraCtrl!.initialize();
      return _cameraCtrl;
    } catch (_) {
      return null;
    }
  }

  // ── Process Frame ─────────────────────────────────────────────
  Future<ScanResult?> processFrame(CameraImage image) async {
    if (_isProcessing || _disposed) return null;
    _isProcessing = true;

    try {
      final inputImage = _buildInputImage(image);
      if (inputImage == null) return null;

      // Step 1: Try barcode first (faster)
      final barcodes = await _barcodeScanner.processImage(inputImage);
      if (barcodes.isNotEmpty) {
        final code = barcodes.first.rawValue;
        if (code != null && code.isNotEmpty) {
          return ScanResult(mode: ScanMode.barcode, barcode: code);
        }
      }

      // Step 2: AI label detection
      final labels = await _imageLabeler.processImage(inputImage);
      if (labels.isNotEmpty) {
        final top = labels.reduce((a, b) => a.confidence > b.confidence ? a : b);
        if (top.confidence > 0.65) {
          return ScanResult(
            mode: ScanMode.aiLabel,
            label: top.label,
            confidence: top.confidence,
          );
        }
      }

      return ScanResult(mode: ScanMode.idle);
    } catch (_) {
      return null;
    } finally {
      _isProcessing = false;
    }
  }

  // ── Build InputImage from CameraImage ─────────────────────────
  InputImage? _buildInputImage(CameraImage image) {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation0deg,
          format: defaultTargetPlatform == TargetPlatform.android
              ? InputImageFormat.nv21
              : InputImageFormat.bgra8888,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  // ── Torch ─────────────────────────────────────────────────────
  Future<void> toggleTorch() async {
    try {
      final mode = _cameraCtrl?.value.flashMode == FlashMode.torch
          ? FlashMode.off
          : FlashMode.torch;
      await _cameraCtrl?.setFlashMode(mode);
    } catch (_) {}
  }

  bool get isTorchOn =>
      _cameraCtrl?.value.flashMode == FlashMode.torch;

  // ── Dispose ───────────────────────────────────────────────────
  Future<void> dispose() async {
    _disposed = true;
    await _cameraCtrl?.stopImageStream();
    await _cameraCtrl?.dispose();
    _barcodeScanner.close();
    _imageLabeler.close();
  }
}