import 'package:flutter/material.dart';

import 'services/assistant_service.dart';

class AssistantScreen extends StatefulWidget {
  final AssistantService service;

  const AssistantScreen({super.key, required this.service});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  String? _message;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    final message = await widget.service.generateMessage();
    if (!mounted) return;
    setState(() {
      _message = message;
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
