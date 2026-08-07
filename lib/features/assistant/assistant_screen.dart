import 'package:flutter/material.dart';

import 'conversation/assistant_conversation_controller.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key, required this.controller});

  final AssistantConversationController controller;

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _wasNearBottom = true;
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_conversationChanged);
    _scrollController.addListener(_trackScrollPosition);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void didUpdateWidget(covariant AssistantScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_conversationChanged);
    widget.controller.addListener(_conversationChanged);
  }

  void _trackScrollPosition() {
    if (!_scrollController.hasClients) return;
    _wasNearBottom =
        _scrollController.position.maxScrollExtent - _scrollController.offset <
        96;
  }

  void _conversationChanged() {
    if (!mounted) return;
    final addedMessage = widget.controller.messages.length > _lastMessageCount;
    _lastMessageCount = widget.controller.messages.length;
    setState(() {});
    if (_wasNearBottom || addedMessage) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _scrollToBottom() {
    if (!mounted || !_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _send() async {
    final text = _inputController.text;
    if (text.trim().isEmpty || widget.controller.isGenerating) return;
    _inputController.clear();
    _wasNearBottom = true;
    await widget.controller.send(text);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_conversationChanged);
    _scrollController
      ..removeListener(_trackScrollPosition)
      ..dispose();
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.controller.messages;
    final generating = widget.controller.isGenerating;
    final awaitingFirstChunk =
        generating &&
        (messages.isEmpty ||
            messages.last.role == AssistantMessageRole.user);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(children: [
              Expanded(child: Text('WardrobeGPT',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900))),
              CircleAvatar(child: Icon(Icons.auto_awesome)),
            ]),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                key: const ValueKey('wardrobe-gpt-conversation'),
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 12),
                itemCount: messages.length + (awaitingFirstChunk ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == messages.length) {
                    return const _ThinkingMessage();
                  }
                  return _MessageBubble(message: messages[index]);
                },
              ),
            ),
            TextField(
              controller: _inputController,
              enabled: !generating,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                labelText: 'Votre demande',
                hintText: "Que mettre aujourd'hui ?",
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: generating ? 'Génération en cours' : 'Envoyer',
                  onPressed: generating ? null : _send,
                  icon: const Icon(Icons.send),
                ),
              ),
            ),
            if (generating) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: widget.controller.stop,
                icon: const Icon(Icons.stop),
                label: const Text('Arrêter'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final AssistantMessage message;

  @override
  Widget build(BuildContext context) {
    final user = message.role == AssistantMessageRole.user;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .82,
        ),
        child: Card(
          color: user ? Theme.of(context).colorScheme.primaryContainer : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Semantics(
              label: user ? 'Utilisateur' : 'Assistant',
              child: SelectableText(message.content),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThinkingMessage extends StatelessWidget {
  const _ThinkingMessage();

  @override
  Widget build(BuildContext context) => const Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox.square(dimension: 16,
          child: CircularProgressIndicator(strokeWidth: 2)),
        SizedBox(width: 10),
        Text('WardrobeGPT réfléchit…'),
      ]),
    ),
  );
}
