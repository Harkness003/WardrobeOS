import 'package:flutter/material.dart';

import 'models/assistant_request.dart';
import 'services/wardrobe_gpt_service.dart';

class AssistantScreen extends StatefulWidget {
  final WardrobeGptService? service;

  const AssistantScreen({super.key, this.service});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  late final WardrobeGptService _service;
  String? _message;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? WardrobeGptService();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    final response = await _service.generate(const AssistantRequest());
    if (!mounted) return;
    setState(() {
      _message = response.message;
      _isLoading = false;
    });
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
              child: Center(
                child:
                    _isLoading
                        ? const CircularProgressIndicator()
                        : Text(
                          _message ?? '',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
              ),
            ),
            FilledButton.icon(
              onPressed: _isLoading ? null : _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualiser'),
            ),
          ],
        ),
      ),
    );
  }
}
