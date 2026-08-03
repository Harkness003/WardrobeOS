import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../weather/services/weather_service.dart';
import '../daily_brief/daily_brief_models.dart';
import '../daily_brief/daily_brief_service.dart';
import '../wardrobe/wardrobe_controller.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback openWardrobe;
  final VoidCallback openAssistant;
  final VoidCallback openOutfits;
  final VoidCallback openScanner;
  final WeatherService weatherService;
  final DailyBriefService dailyBriefService;

  const DashboardScreen({
    super.key,
    required this.openWardrobe,
    required this.openAssistant,
    required this.openOutfits,
    required this.openScanner,
    required this.weatherService,
    required this.dailyBriefService,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final WardrobeController _wardrobe = WardrobeController();
  Future<DailyBrief>? _brief;
  int _proposal = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _wardrobe.load();
    if (!mounted) return;
    setState(() {
      _proposal = 0;
      _brief = widget.dailyBriefService.build(_wardrobe.garments);
    });
  }

  @override
  void dispose() {
    _wardrobe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          children: [
            const Text('Bonjour', style: TextStyle(fontSize: 31, fontWeight: FontWeight.w900, letterSpacing: -1)),
            const SizedBox(height: 4),
            Text('Voici ton Daily Brief', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 22),
            if (_brief == null)
              const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()))
            else
              FutureBuilder<DailyBrief>(
                future: _brief,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    if (snapshot.hasError) return _EmptyBrief(onRetry: _load);
                    return const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()));
                  }
                  final brief = snapshot.requireData;
                  if (brief.cards.isEmpty) return _EmptyBrief(onRetry: widget.openScanner);
                  return Column(
                    children: [
                      for (final card in brief.cards) ...[
                        _BriefCard(
                          card: card,
                          outfit: card.type == DailyBriefCardType.outfit && brief.outfitProposals.isNotEmpty
                              ? brief.outfitProposals[_proposal.clamp(0, brief.outfitProposals.length - 1)]
                              : null,
                          onWhy: () => _showWhy(context, (card.data as DailyOutfitBrief).explanation),
                          onAlternative: brief.outfitProposals.length < 2 ? null : () => setState(() => _proposal = (_proposal + 1) % brief.outfitProposals.length),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  static void _showWhy(BuildContext context, String explanation) {
    showModalBottomSheet<void>(context: context, builder: (context) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Pourquoi cette tenue ?', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12), Text(explanation), const SizedBox(height: 12),
      ]),
    ));
  }
}

class _BriefCard extends StatelessWidget {
  final DailyBriefCard<Object> card;
  final DailyOutfitBrief? outfit;
  final VoidCallback onWhy;
  final VoidCallback? onAlternative;

  const _BriefCard({required this.card, required this.outfit, required this.onWhy, required this.onAlternative});

  @override
  Widget build(BuildContext context) {
    final (icon, title) = switch (card.type) {
      DailyBriefCardType.outfit => (Icons.auto_awesome, 'Tenue du jour'),
      DailyBriefCardType.weather => (Icons.cloud_outlined, 'Météo'),
      DailyBriefCardType.observation => (Icons.insights_outlined, 'Observation'),
      DailyBriefCardType.stylist => (Icons.format_quote_rounded, 'Conseil du styliste'),
      DailyBriefCardType.care => (Icons.cleaning_services_outlined, 'Entretien'),
      DailyBriefCardType.goal => (Icons.flag_outlined, 'Objectif'),
    };
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, color: AppTheme.gold), const SizedBox(width: 10), Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.1))]),
          const SizedBox(height: 16),
          _content(context),
        ]),
      ),
    );
  }

  Widget _content(BuildContext context) {
    if (card.type == DailyBriefCardType.outfit && outfit != null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(outfit!.garments.map((item) => item.name).join(' · '), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))), _Confidence(value: outfit!.confidence)]),
        const SizedBox(height: 8), Text(outfit!.explanation, maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 14), Wrap(spacing: 8, runSpacing: 8, children: outfit!.garments.map((item) => Chip(label: Text(item.name))).toList()),
        const SizedBox(height: 12), Row(children: [TextButton(onPressed: onWhy, child: const Text('Pourquoi ?')), const Spacer(), TextButton(onPressed: onAlternative, child: const Text('Autre proposition'))]),
      ]);
    }
    if (card.data is DailyWeatherBrief) {
      final value = card.data as DailyWeatherBrief;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${value.weather.temperature.round()} °C  ·  Pluie ${value.isRaining ? 'prévue' : 'non prévue'}  ·  Vent ${value.weather.windSpeed.round()} km/h', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8), Text(value.impact),
      ]);
    }
    if (card.data is DailyGoalBrief) {
      final value = card.data as DailyGoalBrief;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 7), Text(value.contribution)]);
    }
    return Text(card.data.toString(), style: const TextStyle(fontSize: 16, height: 1.45));
  }
}

class _Confidence extends StatelessWidget {
  final int value;
  const _Confidence({required this.value});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: AppTheme.gold.withValues(alpha: .16), borderRadius: BorderRadius.circular(20)),
    child: Text('$value %', style: const TextStyle(fontWeight: FontWeight.w900)),
  );
}

class _EmptyBrief extends StatelessWidget {
  final VoidCallback onRetry;
  const _EmptyBrief({required this.onRetry});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
    const Icon(Icons.checkroom_outlined, size: 42), const SizedBox(height: 12),
    const Text('Ton brief se prépare', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
    const SizedBox(height: 7), const Text('Ajoute quelques pièces pour recevoir des recommandations personnalisées.', textAlign: TextAlign.center),
    const SizedBox(height: 14), FilledButton(onPressed: onRetry, child: const Text('Continuer')),
  ])));
}
