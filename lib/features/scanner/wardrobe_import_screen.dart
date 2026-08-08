import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/image_storage_service.dart';
import 'analysis/wardrobe_import_service.dart';
import 'capture/garment_capture.dart';

class WardrobeImportScreen extends StatefulWidget {
  final CameraCaptureSession? cameraCapture;
  final GarmentCapture? fallbackCapture;
  const WardrobeImportScreen({super.key, this.cameraCapture, this.fallbackCapture});
  @override
  State<WardrobeImportScreen> createState() => _WardrobeImportScreenState();
}

class _WardrobeImportScreenState extends State<WardrobeImportScreen> with WidgetsBindingObserver {
  late final CameraCaptureSession capture;
  late final GarmentCapture fallbackCapture;
  final service = WardrobeImportService.instance;
  WardrobeImportTask? lastCapture;
  bool capturing = false;
  bool cameraLoading = true;
  String? cameraError;
  FlashMode flashMode = FlashMode.auto;
  String message = 'Cadrez un vêtement, puis photographiez-le.';

  @override
  void initState() {
    super.initState();
    capture = widget.cameraCapture ?? CameraGarmentCapture();
    fallbackCapture = widget.fallbackCapture ?? ImagePickerGarmentCapture();
    WidgetsBinding.instance.addObserver(this);
    service.addListener(_refresh);
    service.initialize();
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      service.resume();
      _initializeCamera();
    } else if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      unawaited(capture.suspend());
      if (mounted) { setState(() => cameraLoading = true); }
    }
  }

  Future<void> _initializeCamera() async {
    if (!mounted) { return; }
    setState(() { cameraLoading = true; cameraError = null; });
    try {
      await capture.resume();
      if (mounted) { setState(() => cameraLoading = false); }
    } on CameraException catch (error) {
      if (!mounted) { return; }
      setState(() {
        cameraLoading = false;
        cameraError = error.code == 'CameraAccessDenied' || error.code == 'CameraAccessDeniedWithoutPrompt'
            ? 'Accès à la caméra refusé. Autorisez-le dans les réglages ou utilisez la caméra système.'
            : 'La caméra intégrée est indisponible. Vous pouvez poursuivre avec la caméra système.';
      });
    } catch (_) {
      if (mounted) { setState(() { cameraLoading = false; cameraError = 'Impossible d’initialiser la caméra intégrée.'; }); }
    }
  }

  void _refresh() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    service.removeListener(_refresh);
    unawaited(capture.dispose());
    super.dispose();
  }

  Future<void> _capture({bool useFallback = false}) async {
    if (capturing) { return; }
    final watch = Stopwatch()..start();
    setState(() => capturing = true);
    String? persisted;
    try {
      final photoPath = await (useFallback ? fallbackCapture : capture).capture();
      if (photoPath == null) { return; }
      persisted = await ImageStorageService.persist(photoPath);
      watch.stop();
      final task = await service.enqueue(persisted, captureDuration: watch.elapsed);
      persisted = null;
      await HapticFeedback.mediumImpact();
      if (mounted) setState(() {
        lastCapture = task;
        message = 'Photo enregistrée — vous pouvez continuer.';
      });
    } catch (_) {
      if (persisted != null) { await File(persisted).delete().catchError((_) => File(persisted!)); }
      if (mounted) { setState(() => message = 'Impossible d’enregistrer la photo. Réessayez.'); }
    } finally {
      if (mounted) { setState(() => capturing = false); }
    }
  }

  Future<void> _toggleFlash() async {
    final next = switch (flashMode) {
      FlashMode.auto => FlashMode.always,
      FlashMode.always || FlashMode.torch => FlashMode.off,
      FlashMode.off => FlashMode.auto,
    };
    try {
      await capture.setFlashMode(next);
      if (mounted) { setState(() => flashMode = next); }
    } catch (_) {
      if (mounted) { setState(() => message = 'Ce mode de flash n’est pas disponible.'); }
    }
  }

  Future<void> _focus(TapDownDetails details, BoxConstraints constraints) async {
    final point = Offset(
      (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0),
      (details.localPosition.dy / constraints.maxHeight).clamp(0.0, 1.0),
    );
    try { await capture.setFocusPoint(point); } catch (_) { /* Autofocus remains active. */ }
  }

  Future<void> _cancelLast({bool retake = false}) async {
    final task = lastCapture;
    if (task == null) { return; }
    final cancelled = await service.cancel(task.id);
    if (!mounted) { return; }
    setState(() {
      if (cancelled) { lastCapture = null; }
      message = cancelled ? 'Capture annulée.' : 'L’analyse a déjà commencé ; la fiche reste en cours.';
    });
    if (cancelled && retake) { await _capture(); }
  }

  Future<void> _finish() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const WardrobeImportSummaryScreen()));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Importer mon dressing'), actions: [TextButton(onPressed: _finish, child: const Text('Terminer'))]),
    body: SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: Wrap(spacing: 8, runSpacing: 8, children: [
        _Count('Capturés', service.captured), _Count('En attente', service.pending),
        _Count('En analyse', service.analyzing), _Count('Terminés', service.completed),
        _Count('À vérifier', service.needsReview),
      ])),
      Expanded(child: Stack(fit: StackFit.expand, children: [
        ColoredBox(color: Colors.black, child: _cameraBody()),
        if (capture.isInitialized) Positioned(right: 12, top: 12, child: IconButton.filledTonal(
          tooltip: 'Flash : ${flashMode.name}', onPressed: _toggleFlash,
          icon: Icon(flashMode == FlashMode.auto ? Icons.flash_auto : flashMode == FlashMode.off ? Icons.flash_off : Icons.flash_on))),
        if (lastCapture case final task?) Positioned(left: 16, right: 16, bottom: 16,
          child: Card(color: Colors.black87, child: Padding(padding: const EdgeInsets.all(10), child: Row(children: [
            ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(task.photoPath), width: 64, height: 64, fit: BoxFit.cover)),
            const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Dernière photo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Row(children: [TextButton(onPressed: () => _cancelLast(retake: true), child: const Text('Reprendre')),
                TextButton(onPressed: _cancelLast, child: const Text('Annuler'))]),
            ])),
          ])))),
      ])),
      Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 20), child: Column(children: [
        Text(message, textAlign: TextAlign.center), const SizedBox(height: 12),
        Semantics(label: 'Photographier le vêtement suivant', button: true, child: FloatingActionButton.large(
          heroTag: 'bulkCapture', onPressed: capturing || !capture.isInitialized ? null : _capture,
          child: Icon(capturing ? Icons.hourglass_top : Icons.camera_alt))),
        const SizedBox(height: 8), Text(service.analyzing == 0 ? 'Prêt pour la prochaine photo' : '${service.analyzing} vêtement(s) en cours d’analyse'),
      ])),
    ])),
  );

  Widget _cameraBody() {
    if (cameraLoading) { return const Center(child: CircularProgressIndicator()); }
    if (cameraError case final error?) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.no_photography_outlined, color: Colors.white, size: 56),
        const SizedBox(height: 12), Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 16), FilledButton.icon(onPressed: capturing ? null : () => _capture(useFallback: true),
          icon: const Icon(Icons.open_in_new), label: const Text('Utiliser la caméra système')),
        TextButton(onPressed: _initializeCamera, child: const Text('Réessayer')),
      ])));
    }
    final controller = capture.controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: Text('Aucune caméra disponible', style: TextStyle(color: Colors.white)));
    }
    return LayoutBuilder(builder: (context, constraints) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) => _focus(details, constraints),
      child: Center(child: CameraPreview(controller)),
    ));
  }
}

class _Count extends StatelessWidget {
  final String label; final int value;
  const _Count(this.label, this.value);
  @override Widget build(BuildContext context) => Chip(label: Text('$label  $value'));
}

class WardrobeImportSummaryScreen extends StatefulWidget {
  const WardrobeImportSummaryScreen({super.key});
  @override State<WardrobeImportSummaryScreen> createState() => _WardrobeImportSummaryScreenState();
}

class _WardrobeImportSummaryScreenState extends State<WardrobeImportSummaryScreen> {
  final service = WardrobeImportService.instance;
  @override void initState() { super.initState(); service.addListener(_refresh); }
  void _refresh() { if (mounted) setState(() {}); }
  @override void dispose() { service.removeListener(_refresh); super.dispose(); }
  @override Widget build(BuildContext context) {
    final active = service.pending + service.analyzing;
    return Scaffold(appBar: AppBar(title: const Text('Récapitulatif')), body: ListView(padding: const EdgeInsets.all(20), children: [
      Text('${service.captured} vêtements capturés', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 16), Text('${service.completed + service.needsReview} fiches déjà créées'),
      Text('$active analyses en cours'), Text('${service.needsReview} nécessitent votre attention'), Text('${service.failed} échecs'),
      if (active > 0) const Padding(padding: EdgeInsets.only(top: 12), child: Text('Vous pouvez fermer cet écran : les analyses continuent tant que l’application reste active.')),
      const SizedBox(height: 24),
      if (service.needsReview > 0) OutlinedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WardrobeImportReviewScreen())), child: const Text('Ouvrir « À vérifier »')),
      if (service.failed > 0) FilledButton.tonal(onPressed: () async { for (final task in service.tasks.where((task) => task.status == WardrobeImportStatus.failed)) { await service.retry(task.id); } }, child: const Text('Réessayer les échecs')),
      FilledButton(onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst), child: const Text('Revenir au Dressing')),
    ]));
  }
}

class WardrobeImportReviewScreen extends StatelessWidget {
  const WardrobeImportReviewScreen({super.key});
  @override Widget build(BuildContext context) {
    final tasks = WardrobeImportService.instance.tasks.where((task) => task.status == WardrobeImportStatus.needsReview).toList();
    return Scaffold(appBar: AppBar(title: const Text('À vérifier')), body: ListView.builder(itemCount: tasks.length, itemBuilder: (_, index) {
      final task = tasks[index];
      return ListTile(leading: Image.file(File(task.photoPath), width: 52, height: 52, fit: BoxFit.cover),
        title: Text(task.quickResult?.suggestedName ?? 'Vêtement à identifier'),
        subtitle: Text(task.userMessage ?? 'Vérification conseillée'));
    }));
  }
}
