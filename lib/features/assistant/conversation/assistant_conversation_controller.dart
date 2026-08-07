import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/assistant_service.dart';

enum AssistantMessageRole { user, assistant }

@immutable
class AssistantMessage {
  const AssistantMessage({
    required this.id,
    required this.role,
    required this.content,
  });

  final int id;
  final AssistantMessageRole role;
  final String content;

  AssistantMessage copyWith({String? content}) => AssistantMessage(
    id: id,
    role: role,
    content: content ?? this.content,
  );
}

/// Owns the single in-memory conversation displayed by the assistant screen.
/// Requests are deliberately serialized: while a response is being generated,
/// another send is rejected rather than interleaved with the active stream.
class AssistantConversationController extends ChangeNotifier {
  AssistantConversationController({required AssistantService service})
    : _service = service;

  final AssistantService _service;
  final List<AssistantMessage> _messages = [];
  StreamSubscription<String>? _generation;
  Completer<void>? _completion;
  int _nextId = 0;
  bool _isGenerating = false;
  bool _disposed = false;

  List<AssistantMessage> get messages => List.unmodifiable(_messages);
  bool get isGenerating => _isGenerating;

  Future<bool> send(String text) async {
    final request = text.trim();
    if (request.isEmpty || _isGenerating) return false;

    _isGenerating = true;
    _messages.add(AssistantMessage(
      id: _nextId++,
      role: AssistantMessageRole.user,
      content: request,
    ));
    _notify();

    int? responseId;
    final completion = Completer<void>();
    _completion = completion;
    _generation = _service.generateMessageStream(userMessage: request).listen(
      (chunk) {
        if (_disposed || chunk.isEmpty) return;
        if (responseId == null) {
          responseId = _nextId++;
          _messages.add(AssistantMessage(
            id: responseId!,
            role: AssistantMessageRole.assistant,
            content: chunk,
          ));
        } else {
          final index = _messages.indexWhere((item) => item.id == responseId);
          _messages[index] = _messages[index].copyWith(
            content: '${_messages[index].content}$chunk',
          );
        }
        _notify();
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!_disposed) {
          _messages.add(AssistantMessage(
            id: _nextId++,
            role: AssistantMessageRole.assistant,
            content: error is AssistantTechnicalException
                ? error.userMessage
                : AssistantTechnicalException.defaultUserMessage,
          ));
          _finish();
        }
        if (!completion.isCompleted) completion.complete();
      },
      onDone: () {
        if (!_disposed) _finish();
        if (!completion.isCompleted) completion.complete();
      },
      cancelOnError: true,
    );
    await completion.future;
    return true;
  }

  Future<void> stop() async {
    await _generation?.cancel();
    _finish();
  }

  void _finish() {
    _generation = null;
    final completion = _completion;
    if (completion != null && !completion.isCompleted) completion.complete();
    _completion = null;
    _isGenerating = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation?.cancel();
    final completion = _completion;
    if (completion != null && !completion.isCompleted) completion.complete();
    super.dispose();
  }
}
