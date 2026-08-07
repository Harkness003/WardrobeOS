import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/core/diagnostics/diagnostic_service.dart';

void main() {
  final service = DiagnosticService.instance;

  tearDown(() {
    service.clear();
    service.setEnabled(false);
  });

  test('disabled diagnostics allocate no correlation id and publish nothing', () {
    service.setEnabled(false);
    expect(service.newCorrelationId('daily'), isNull);
    service.publish(module: DiagnosticModule.daily, level: AppDiagnosticLevel.error,
      state: 'error', summary: 'hidden', source: 'test');
    expect(service.entries, isEmpty);
  });

  test('pipeline entries share a correlation id', () {
    service.setEnabled(true);
    final id = service.newCorrelationId('daily');
    for (final step in ['started', 'rendered']) {
      service.publish(module: DiagnosticModule.daily, level: AppDiagnosticLevel.info,
        state: step, summary: step, source: 'test', correlationId: id);
    }
    expect(service.entries.map((entry) => entry.correlationId).toSet(), {id});
  });

  test('single-entry export excludes other modules and secrets', () {
    service.setEnabled(true);
    service.publish(module: DiagnosticModule.daily, level: AppDiagnosticLevel.error,
      state: 'failed', summary: 'daily', source: 'test',
      details: const {'accessToken': 'secret', 'safeCount': 2});
    service.publish(module: DiagnosticModule.agenda, level: AppDiagnosticLevel.info,
      state: 'ready', summary: 'agenda', source: 'test');

    final report = jsonDecode(service.exportEntry(
      service.filtered(module: DiagnosticModule.daily).single)) as Map;
    final encoded = jsonEncode(report);
    expect(encoded, contains('Daily'));
    expect(encoded, isNot(contains('Agenda')));
    expect(encoded, isNot(contains('secret')));
    expect(encoded, contains('safeCount'));
  });
}
