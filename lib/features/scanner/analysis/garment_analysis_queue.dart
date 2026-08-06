import 'dart:async';

/// Serial execution primitive for the future bulk-import flow.
///
/// A job owns its local photo and can create a draft as soon as its quick pass
/// completes. Slow enrichment remains asynchronous while later jobs wait their
/// turn, avoiding concurrent vision calls and excessive memory pressure.
class GarmentAnalysisQueue {
  Future<void> _tail = Future<void>.value();

  Future<T> enqueue<T>(Future<T> Function() job) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await job());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}
