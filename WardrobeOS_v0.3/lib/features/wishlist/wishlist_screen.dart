import 'package:flutter/material.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final items = <String>[];

  void addItem() {
    showDialog<void>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Ajouter à la wishlist'),
          content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Nom de l’article')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  setState(() => items.add(controller.text.trim()));
                }
                Navigator.pop(context);
              },
              child: const Text('Ajouter'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: addItem,
          icon: const Icon(Icons.add),
          label: const Text('Ajouter'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
          children: [
            const Text('Wishlist', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -1)),
            const SizedBox(height: 4),
            const Text('Base locale temporaire pour les achats envisagés'),
            const SizedBox(height: 18),
            if (items.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 46, horizontal: 20),
                  child: Column(
                    children: [
                      Icon(Icons.favorite_border, size: 54, color: Color(0xFFC89B4A)),
                      SizedBox(height: 14),
                      Text('Ta wishlist est vide', style: TextStyle(fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              )
            else
              ...items.asMap().entries.map(
                (entry) => Dismissible(
                  key: ValueKey('${entry.key}-${entry.value}'),
                  onDismissed: (_) => setState(() => items.removeAt(entry.key)),
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.shopping_bag_outlined)),
                      title: Text(entry.value, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: const Text('À analyser plus tard'),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
