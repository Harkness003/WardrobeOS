import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wardrobeos/features/assistant/ai/llm_provider.dart';
import 'package:wardrobeos/features/assistant/context/assistant_context_builder.dart';
import 'package:wardrobeos/features/assistant/conversation/assistant_conversation_controller.dart';
import 'package:wardrobeos/features/assistant/services/assistant_service.dart';
import 'package:wardrobeos/features/outfits/outfits_controller.dart';
import 'package:wardrobeos/features/wardrobe/wardrobe_controller.dart';
import 'package:wardrobeos/weather/models/weather_data.dart';
import 'package:wardrobeos/weather/services/weather_service.dart';

class _Weather implements WeatherService {
  @override
  void clearCache() {}

  @override
  Future<WeatherData> getCurrentWeather({bool forceRefresh = false}) async =>
      throw StateError('optional weather unavailable');
}

class _QueueProvider implements StreamingLlmProvider {
  _QueueProvider(this.responses);
  final List<List<String>> responses;
  int calls = 0;

  @override
  Future<String> generate(String prompt) async => responses[calls++].join();

  @override
  Stream<String> generateStream(String prompt) async* {
    final chunks = responses[calls++];
    for (final chunk in chunks) {
      yield chunk;
    }
  }
}

class _FailingProvider implements StreamingLlmProvider {
  @override
  Future<String> generate(String prompt) => throw const LlmNetworkException();

  @override
  Stream<String> generateStream(String prompt) async* {
    throw const LlmNetworkException();
  }
}

class _ControlledProvider implements StreamingLlmProvider {
  final stream = StreamController<String>();
  int calls = 0;

  @override
  Future<String> generate(String prompt) async => '';

  @override
  Stream<String> generateStream(String prompt) {
    calls++;
    return stream.stream;
  }
}

AssistantService _service(LlmProvider provider) => AssistantService(
  contextBuilder: AssistantContextBuilder(
    weatherService: _Weather(),
    wardrobeController: WardrobeController()..loading = false,
    outfitsController: OutfitsController()..loading = false,
  ),
  llmProvider: provider,
);

void main() {
  test('ajoute chaque tour et assemble les fragments dans le même message', () async {
    final controller = AssistantConversationController(
      service: _service(_QueueProvider([
        ['Bonjour ', 'à toi'],
        ['Une seconde réponse'],
      ])),
    );

    await controller.send('Premier message');
    await controller.send('Deuxième message');

    expect(controller.messages.map((message) => message.role), [
      AssistantMessageRole.user,
      AssistantMessageRole.assistant,
      AssistantMessageRole.user,
      AssistantMessageRole.assistant,
    ]);
    expect(controller.messages.map((message) => message.content), [
      'Premier message',
      'Bonjour à toi',
      'Deuxième message',
      'Une seconde réponse',
    ]);
  });

  test('conserve intégralement une réponse longue', () async {
    final longResponse = List.filled(500, 'contenu').join(' ');
    final controller = AssistantConversationController(
      service: _service(_QueueProvider([[longResponse]])),
    );

    await controller.send('Réponse détaillée');

    expect(controller.messages.last.content, longResponse);
  });

  test('un dressing vide produit une réponse métier sans appeler le provider', () async {
    final provider = _QueueProvider([
      ['ne doit pas être utilisé'],
    ]);
    final controller = AssistantConversationController(
      service: _service(provider),
    );

    await controller.send("Que mettre aujourd'hui ?");

    expect(controller.messages.last.content, contains('dressing est vide'));
    expect(controller.messages.last.content, isNot(contains('indisponible')));
    expect(provider.calls, 0);
  });

  test('une panne technique ajoute un message récupérable sans effacer le fil', () async {
    final controller = AssistantConversationController(
      service: _service(_QueueProvider([['Réponse initiale']])),
    );
    await controller.send('Bonjour');
    final failing = AssistantConversationController(
      service: _service(_FailingProvider()),
    );

    await failing.send('Essaie');

    expect(failing.messages, hasLength(2));
    expect(failing.messages.first.content, 'Essaie');
    expect(failing.messages.last.content, contains('réessayer'));
    expect(failing.isGenerating, isFalse);
    expect(controller.messages.last.content, 'Réponse initiale');
  });

  test('refuse un double envoi pendant le flux actif', () async {
    final provider = _ControlledProvider();
    final controller = AssistantConversationController(
      service: _service(provider),
    );

    final first = controller.send('Une demande');
    await Future<void>.delayed(Duration.zero);
    expect(await controller.send('Doublon'), isFalse);
    expect(provider.calls, 1);
    await provider.stream.close();
    await first;
  });
}
