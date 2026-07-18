import 'package:flutter/material.dart';

class OutfitsScreen extends StatefulWidget {
  const OutfitsScreen({super.key});

  @override
  State<OutfitsScreen> createState() => _OutfitsScreenState();
}

class _OutfitsScreenState extends State<OutfitsScreen> {
  bool generated = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
        children: [
          const Text('Tenues', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -1)),
          const SizedBox(height: 4),
          const Text('Première base du générateur de looks'),
          const SizedBox(height: 18),
          const _Selector(icon: Icons.event_outlined, title: 'Occasion', value: 'Décontracté'),
          const SizedBox(height: 10),
          const _Selector(icon: Icons.wb_sunny_outlined, title: 'Météo', value: 'À définir'),
          const SizedBox(height: 10),
          const _Selector(icon: Icons.style_outlined, title: 'Style', value: 'Polyvalent'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => setState(() => generated = true),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Générer une démonstration'),
          ),
          const SizedBox(height: 22),
          if (!generated)
            const _EmptyState()
          else
            const _OutfitDemo(),
        ],
      ),
    );
  }
}

class _Selector extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _Selector({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFC89B4A)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(value),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 42, horizontal: 20),
        child: Column(
          children: [
            Icon(Icons.auto_awesome_outlined, size: 52, color: Color(0xFFC89B4A)),
            SizedBox(height: 14),
            Text('Les tenues générées apparaîtront ici', style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _OutfitDemo extends StatelessWidget {
  const _OutfitDemo();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Row(
              children: [
                Expanded(child: Text('Look décontracté', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                Chip(label: Text('92 %')),
              ],
            ),
            const SizedBox(height: 18),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Piece(icon: Icons.checkroom, label: 'Haut'),
                _Piece(icon: Icons.straighten, label: 'Bas'),
                _Piece(icon: Icons.directions_walk, label: 'Chaussures'),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Cette proposition est encore simulée. Elle sera reliée au dressing SQLite dans un prochain sprint.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Piece extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Piece({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(radius: 28, child: Icon(icon)),
        const SizedBox(height: 7),
        Text(label),
      ],
    );
  }
}
