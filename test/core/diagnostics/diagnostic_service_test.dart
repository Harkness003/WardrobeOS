import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/core/diagnostics/diagnostic_service.dart';

void main() {
  final service = DiagnosticService.instance;

  setUp(() {
    service.setEnabled(false);
    service.clear();
  });

  test('ne collecte rien quand le mode développeur est désactivé', () {
    service.publish(module: DiagnosticModule.daily, level: DiagnosticLevel.info,
      state: 'test', summary: 'test', source: 'test');
    expect(service.entries, isEmpty);
  });

  test('conserve au plus 100 entrées par module en FIFO', () {
    service.setEnabled(true);
    for (var index = 0; index < 105; index++) {
      service.publish(module: DiagnosticModule.scanner, level: DiagnosticLevel.success,
        state: '$index', summary: 'analyse', source: 'test');
    }
    final entries = service.filtered(module: DiagnosticModule.scanner);
    expect(entries, hasLength(100));
    expect(entries.map((entry) => entry.state), isNot(contains('0')));
    expect(entries.map((entry) => entry.state), contains('104'));
  });

  test('filtre par niveau et module puis purge un module', () {
    service.setEnabled(true);
    service.publish(module: DiagnosticModule.daily, level: DiagnosticLevel.error,
      state: 'erreur', summary: 'daily', source: 'test');
    service.publish(module: DiagnosticModule.weather, level: DiagnosticLevel.success,
      state: 'ok', summary: 'weather', source: 'test');
    expect(service.filtered(levels: {DiagnosticLevel.error}), hasLength(1));
    service.clear(DiagnosticModule.daily);
    expect(service.entries.single.module, DiagnosticModule.weather);
  });

  test('exporte sans secrets, prompts, photos ni chemins privés', () {
    service.setEnabled(true);
    service.publish(module: DiagnosticModule.wardrobeGpt, level: DiagnosticLevel.error,
      state: 'Bearer secret-token', summary: 'sk-abcdefghijklmnopqrstuvwxyz',
      source: '/home/alex/private/file.dart', reason: 'Exception: raw failure',
      details: {'token': 'oauth-secret', 'prompt': 'prompt complet',
        'photoPath': '/data/user/0/private.jpg', 'intention': 'dailyOutfit'});
    final report = service.exportReport();
    expect(report, contains('[MASQUÉ]'));
    expect(report, isNot(contains('oauth-secret')));
    expect(report, isNot(contains('prompt complet')));
    expect(report, isNot(contains('private.jpg')));
    expect(report, isNot(contains('Exception: raw failure')));
    expect(report, contains('dailyOutfit'));
  });
}
