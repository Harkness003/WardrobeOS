class AiOrchestrationCacheEntry {
  final Object? value;
  final DateTime storedAt;

  const AiOrchestrationCacheEntry({required this.value, required this.storedAt});
}

abstract interface class AiOrchestrationCache {
  Future<AiOrchestrationCacheEntry?> read(String key);
  Future<void> write(String key, AiOrchestrationCacheEntry entry);
  Future<void> remove(String key);
  Future<void> clear();
}

class MemoryAiOrchestrationCache implements AiOrchestrationCache {
  final Map<String, AiOrchestrationCacheEntry> _entries = {};

  @override
  Future<AiOrchestrationCacheEntry?> read(String key) async => _entries[key];

  @override
  Future<void> write(String key, AiOrchestrationCacheEntry entry) async {
    _entries[key] = entry;
  }

  @override
  Future<void> remove(String key) async => _entries.remove(key);

  @override
  Future<void> clear() async => _entries.clear();
}
