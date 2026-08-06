import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RC7.8.2 integrated capture contract', () {
    late String request;
    late String provider;
    late String service;
    late String capture;
    late String screen;

    setUpAll(() {
      request = File('lib/features/scanner/ai/garment_analysis_request.dart').readAsStringSync();
      provider = File('lib/features/scanner/ai/openai_garment_vision_analyzer.dart').readAsStringSync();
      service = File('lib/features/scanner/analysis/wardrobe_import_service.dart').readAsStringSync();
      capture = File('lib/features/scanner/capture/garment_capture.dart').readAsStringSync();
      screen = File('lib/features/scanner/wardrobe_import_screen.dart').readAsStringSync();
    });

    test('bulk import explicitly supplies no seasons and provider omits an empty list', () {
      expect(request, contains('required this.allowedSeasons'));
      expect(service, contains('allowedSeasons: const <String>[]'));
      expect(provider, contains("request.allowedSeasons.isEmpty ? ''"));
    });

    test('one testable controller session supports repeated guarded captures', () {
      expect(capture, contains('abstract interface class CameraCaptureSession'));
      expect(capture, contains("if (pending != null) return pending"));
      expect(capture, contains("if (_disposed || _capturing"));
      expect(capture, contains('active.takePicture()'));
      expect(screen, contains('CameraPreview(controller)'));
      expect(screen, contains('persisted = await ImageStorageService.persist(photoPath)'));
      expect(screen, contains('service.enqueue(persisted'));
    });

    test('camera lifecycle releases, resumes and disposes the controller', () {
      expect(screen, contains('AppLifecycleState.paused'));
      expect(screen, contains('capture.suspend()'));
      expect(screen, contains('capture.resume()'));
      expect(screen, contains('capture.dispose()'));
      expect(capture, contains('generation != _generation'));
    });

    test('failure states retain ImagePicker as an explicit fallback', () {
      expect(screen, contains('CameraAccessDenied'));
      expect(screen, contains('Aucune caméra disponible'));
      expect(screen, contains('ImagePickerGarmentCapture()'));
      expect(screen, contains('Utiliser la caméra système'));
    });

    test('retake delegates cancellation and keeps the preview in the tree', () {
      expect(screen, contains('service.cancel(task.id)'));
      expect(screen, contains('_cancelLast(retake: true)'));
      expect(screen, isNot(contains('ImageSource.camera')));
    });
  });
}
