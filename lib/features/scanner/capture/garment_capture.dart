import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

/// Boundary around the current native camera hand-off. A CameraController
/// implementation can replace it later without changing import persistence.
abstract interface class GarmentCapture {
  Future<String?> capture();
}

/// Test seam for the lifecycle of an integrated camera session.
abstract interface class CameraCaptureSession implements GarmentCapture {
  CameraController? get controller;
  bool get isInitialized;
  bool get isCapturing;
  Future<void> initialize();
  Future<void> resume();
  Future<void> suspend();
  Future<void> setFlashMode(FlashMode mode);
  Future<void> setFocusPoint(Offset point);
  Future<void> dispose();
}

class ImagePickerGarmentCapture implements GarmentCapture {
  final ImagePicker picker;
  ImagePickerGarmentCapture({ImagePicker? picker}) : picker = picker ?? ImagePicker();

  @override
  Future<String?> capture() async => (await picker.pickImage(
    source: ImageSource.camera,
    imageQuality: 90,
    maxWidth: 1800,
  ))?.path;
}

/// Long-lived, in-app capture session used by bulk import.
///
/// Keeping controller ownership here makes the screen and the analysis pipeline
/// independent from the camera plugin, and allows the session to be faked.
class CameraGarmentCapture implements CameraCaptureSession {
  CameraController? _controller;
  Future<void>? _initialization;
  bool _disposed = false;
  bool _capturing = false;
  int _generation = 0;

  CameraController? get controller => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  bool get isCapturing => _capturing;

  Future<void> initialize() async {
    if (_disposed || isInitialized) return;
    final pending = _initialization;
    if (pending != null) return pending;
    final operation = _initializeController();
    _initialization = operation;
    try {
      await operation;
    } finally {
      if (identical(_initialization, operation)) _initialization = null;
    }
  }

  Future<void> _initializeController() async {
    final generation = _generation;
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw CameraException('cameraUnavailable', 'Aucune caméra disponible.');
    }
    final selected = cameras.where((camera) => camera.lensDirection == CameraLensDirection.back)
        .firstOrNull ?? cameras.first;
    final next = CameraController(
      selected,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await next.initialize();
    if (_disposed || generation != _generation) {
      await next.dispose();
      return;
    }
    _controller = next;
    try { await next.setFlashMode(FlashMode.auto); } on CameraException { /* Optional hardware feature. */ }
    try { await next.setFocusMode(FocusMode.auto); } on CameraException { /* Autofocus is normally the default. */ }
  }

  @override
  Future<String?> capture() async {
    final active = _controller;
    if (_disposed || _capturing || active == null || !active.value.isInitialized) return null;
    _capturing = true;
    try {
      return (await active.takePicture()).path;
    } finally {
      _capturing = false;
    }
  }

  Future<void> setFlashMode(FlashMode mode) async {
    final active = _controller;
    if (!_disposed && active != null && active.value.isInitialized) await active.setFlashMode(mode);
  }

  Future<void> setFocusPoint(Offset point) async {
    final active = _controller;
    if (!_disposed && active != null && active.value.isInitialized) await active.setFocusPoint(point);
  }

  Future<void> suspend() async {
    _generation++;
    final previous = _controller;
    _controller = null;
    await previous?.dispose();
  }

  Future<void> resume() async {
    await initialize();
    // A permission dialog may send the app inactive while initialization is in
    // flight; in that case suspend invalidates the first controller.
    if (!_disposed && !isInitialized) {
      await Future<void>.delayed(Duration.zero);
      await initialize();
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await suspend();
  }
}
