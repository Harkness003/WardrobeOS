import 'dart:async';
import 'package:flutter/material.dart';

import 'services/assistant_service.dart';
import '../../widgets/outfit_proposal_card.dart';

class AssistantScreen extends StatefulWidget {
  final AssistantService service;

  const AssistantScreen({super.key, required this.service});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _controller = TextEditingController();
  String? _message;
  bool _isLoading = false;
  StreamSubscription<String>? _generation;

  @override
  void dispose() {
    _generation?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final userMessage = _controller.text.trim();
    if (userMessage.isEmpty) return;
    setState(() => _isLoading = true);
    setState(() {
      _message = '';
    });
    _generation = widget.service
        .generateMessageStream(userMessage: userMessage)
        .listen(
          (chunk) {
            if (mounted) setState(() => _message = '${_message ?? ''}$chunk');
          },
          onError: (_) {
            if (!mounted) return;
            setState(() {
              _message = 'WardrobeGPT est momentanément indisponible. Réessayez dans un instant.';
              _isLoading = false;
            });
          },
          onDone: _finishGeneration,
        );
  }

  void _finishGeneration() {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _stop() async {
    await _generation?.cancel();
    _finishGeneration();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Expanded(
                  child: Text(
                    'WardrobeGPT',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                  ),
                ),
                CircleAvatar(child: Icon(Icons.auto_awesome)),
              ],
            ),
            const SizedBox(height: 32),
            Expanded(
              child: ListView(
                children: [
                  for (final proposal in widget.service.lastOutfitProposals)
                    OutfitProposalCard(proposal: proposal),
                  SizedBox(
                    height: 220,
                    child: Center(
                      child:
                          _isLoading && (_message?.isEmpty ?? true)
                              ? const CircularProgressIndicator()
                              : Text(
                                _message ?? 'WardrobeGPT est prêt. Demandez une tenue, un conseil de style ou une idée adaptée à votre journée.',
                                textAlign: TextAlign.start,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                    ),
                  ),
                ],
              ),
            ),
            TextField(
              controller: _controller,
              enabled: !_isLoading,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: const InputDecoration(
                labelText: 'Votre demande',
                hintText: "Que mettre aujourd'hui ?",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _isLoading ? _stop : _send,
              icon: Icon(_isLoading ? Icons.stop : Icons.send),
              label: Text(_isLoading ? 'Arrêter' : 'Envoyer'),
            ),
          ],
        ),
      ),
    );
  }
}
