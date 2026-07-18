import 'package:flutter/material.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final input = TextEditingController();
  final List<_Message> messages = [
    const _Message(
      mine: false,
      text:
          'Bonjour 👋 Je suis WardrobeGPT. Pour le moment je fonctionne en mode démonstration, mais cette base est prête à être reliée à ton dressing.',
    ),
  ];

  void send([String? preset]) {
    final text = (preset ?? input.text).trim();
    if (text.isEmpty) return;
    setState(() {
      messages.add(_Message(mine: true, text: text));
      messages.add(
        const _Message(
          mine: false,
          text:
              'J’ai bien reçu ta demande. L’étape suivante consistera à me connecter aux vêtements enregistrés dans SQLite.',
        ),
      );
    });
    input.clear();
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: Row(
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
          ),
          SizedBox(
            height: 44,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              scrollDirection: Axis.horizontal,
              children: [
                _Prompt(text: 'Tenue pour ce soir', onTap: send),
                _Prompt(text: 'Analyse mon dressing', onTap: send),
                _Prompt(text: 'Que dois-je acheter ?', onTap: send),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (_, index) => _Bubble(message: messages[index]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: input,
                    onSubmitted: (_) => send(),
                    decoration: const InputDecoration(
                      hintText: 'Écris ton message…',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: send,
                  icon: const Icon(Icons.arrow_upward),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Message {
  final bool mine;
  final String text;
  const _Message({required this.mine, required this.text});
}

class _Prompt extends StatelessWidget {
  final String text;
  final void Function(String) onTap;

  const _Prompt({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(label: Text(text), onPressed: () => onTap(text)),
    );
  }
}

class _Bubble extends StatelessWidget {
  final _Message message;
  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color:
              message.mine
                  ? const Color(0xFFC89B4A)
                  : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.mine ? const Color(0xFF171717) : null,
          ),
        ),
      ),
    );
  }
}
