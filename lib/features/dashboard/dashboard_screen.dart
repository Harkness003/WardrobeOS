import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/section_title.dart';

class DashboardScreen extends StatelessWidget {
  final VoidCallback openWardrobe;
  final VoidCallback openAssistant;
  final VoidCallback openOutfits;
  final VoidCallback openScanner;

  const DashboardScreen({
    super.key,
    required this.openWardrobe,
    required this.openAssistant,
    required this.openOutfits,
    required this.openScanner,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
        children: [
          _Header(onNotification: () => _toast(context, 'Aucune notification pour le moment')),
          const SizedBox(height: 22),
          _DailyAssistantCard(onTap: openAssistant),
          const SizedBox(height: 14),
          const Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  icon: Icons.wb_sunny_outlined,
                  value: '18°',
                  label: 'Clair',
                  detail: 'Météo locale',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _MiniMetric(
                  icon: Icons.calendar_today_outlined,
                  value: '20h',
                  label: 'Dîner',
                  detail: 'Prochain événement',
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          SectionTitle(
            title: 'Tenue suggérée',
            action: 'Générer',
            onAction: openOutfits,
          ),
          const SizedBox(height: 12),
          _SuggestedLook(onTap: openOutfits),
          const SizedBox(height: 28),
          const SectionTitle(title: 'Accès rapides'),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.42,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _ActionCard(
                icon: Icons.checkroom,
                title: 'Mon dressing',
                subtitle: 'Gérer mes pièces',
                onTap: openWardrobe,
              ),
              _ActionCard(
                icon: Icons.auto_awesome,
                title: 'Tenues',
                subtitle: 'Créer un look',
                onTap: openOutfits,
              ),
              _ActionCard(
                icon: Icons.camera_alt_outlined,
                title: 'Scanner',
                subtitle: 'Ajouter une pièce',
                onTap: openScanner,
              ),
              _ActionCard(
                icon: Icons.chat_bubble_outline,
                title: 'WardrobeGPT',
                subtitle: 'Poser une question',
                onTap: openAssistant,
              ),
            ],
          ),
          const SizedBox(height: 28),
          const SectionTitle(title: 'Insight du dressing'),
          const SizedBox(height: 12),
          const _InsightCard(),
        ],
      ),
    );
  }

  static void _toast(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onNotification;
  const _Header({required this.onNotification});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bonjour Alex',
                style: TextStyle(
                  fontSize: 31,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              SizedBox(height: 3),
              Text('Ton style, simplifié chaque jour'),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: onNotification,
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
    );
  }
}

class _DailyAssistantCard extends StatelessWidget {
  final VoidCallback onTap;
  const _DailyAssistantCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF151513), Color(0xFF3A3022)],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .16),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              _PremiumIcon(icon: Icons.auto_awesome),
              Spacer(),
              Text(
                'WARDROBE AI',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          const Text(
            'Que veux-tu porter\naujourd’hui ?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 29,
              height: 1.04,
              fontWeight: FontWeight.w900,
              letterSpacing: -.8,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Une réponse adaptée à ton dressing, ton agenda et la météo.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 205,
            child: FilledButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.chat_bubble_outline, size: 19),
              label: const Text('Demander à l’IA'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumIcon extends StatelessWidget {
  final IconData icon;
  const _PremiumIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.gold.withValues(alpha: .3)),
      ),
      child: Icon(icon, color: AppTheme.gold),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final String detail;

  const _MiniMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.gold),
            const SizedBox(height: 15),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(label),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(detail, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _SuggestedLook extends StatelessWidget {
  final VoidCallback onTap;
  const _SuggestedLook({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              height: 190,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFD3C5B3), Color(0xFFF0EBE3)],
                ),
              ),
              child: Stack(
                children: [
                  const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _LookPiece(icon: Icons.checkroom, label: 'Surchemise'),
                        SizedBox(width: 12),
                        _LookPiece(icon: Icons.straighten, label: 'Pantalon'),
                        SizedBox(width: 12),
                        _LookPiece(icon: Icons.directions_walk, label: 'Sneakers'),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 14,
                    right: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '92 %',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Élégant décontracté',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text('Dîner entre amis · 20h'),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LookPiece extends StatelessWidget {
  final IconData icon;
  final String label;
  const _LookPiece({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 88,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .78),
            borderRadius: BorderRadius.circular(21),
          ),
          child: Icon(icon, size: 38, color: const Color(0xFF705C43)),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppTheme.gold),
              const Spacer(),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(19),
        child: Row(
          children: [
            const _PremiumIcon(icon: Icons.lightbulb_outline_rounded),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ton dressing commence ici',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ajoute régulièrement tes pièces pour obtenir des conseils plus précis.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
