import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/outfit_generation/outfit_generation_engine.dart';
import '../../widgets/outfit_proposal_card.dart';
import '../../weather/services/weather_service.dart';
import '../daily_brief/daily_brief_models.dart';
import '../daily_brief/daily_brief_service.dart';

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
  late Stream<DailyBrief> _brief;
  int _proposal = 0;

  @override
  void initState() {
    super.initState();
    _brief = widget.dailyBriefService.watch();
  }

  Future<void> _load() async {
    setState(() {
      _proposal = 0;
      // watch() always asks WardrobeAiContextService for a fresh database
      // snapshot, so recent additions and edits appear after every refresh.
      _brief = widget.dailyBriefService.watch();
    });
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
              StreamBuilder<DailyBrief>(
                stream: _brief,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    if (snapshot.hasError) return _BriefError(onRetry: _load);
                    return const _BriefLoading();
                  }
                  final brief = snapshot.requireData;
                  if (brief.state == DailyBriefState.emptyWardrobe) {
                    return _BriefStateMessage(icon: Icons.checkroom_outlined,
                      title: 'Ton dressing est vide', detail: 'Scanne une première pièce pour générer une tenue complète.',
                      action: widget.openScanner, actionLabel: 'Scanner une pièce');
                  }
                  return Column(
                    children: [
                      if (brief.state != DailyBriefState.available) ...[
                        _DailyStateBanner(state: brief.state, detail: brief.detail),
                        const SizedBox(height: 14),
                      ],
                      for (final card in brief.cards) ...[
                        _BriefCard(
                          card: card,
                          outfit: card.type == DailyBriefCardType.outfit && brief.outfitProposals.isNotEmpty
                              ? brief.outfitProposals[_proposal.clamp(0, brief.outfitProposals.length - 1)]
                              : null,
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

}

class _BriefCard extends StatelessWidget {
  final DailyBriefCard<Object> card;
  final OutfitGenerationProposal? outfit;
  final VoidCallback? onAlternative;

  const _BriefCard({required this.card, required this.outfit, required this.onAlternative});

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
      return Column(children: [
        OutfitProposalCard(proposal: outfit!),
        if (onAlternative != null) Align(alignment: Alignment.centerRight,
          child: TextButton(onPressed: onAlternative, child: const Text('Autre proposition'))),
      ]);
    }
    if (card.data is DailyWeatherBrief) {
      final value = card.data as DailyWeatherBrief;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value.weather.city, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('${value.weather.temperature.round()} °C  ·  ${value.weather.description}  ·  Pluie ${value.isRaining ? 'prévue' : 'non prévue'}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
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

class _BriefStateMessage extends StatelessWidget {
  final IconData icon; final String title; final String detail;
  final VoidCallback? action; final String? actionLabel;
  const _BriefStateMessage({required this.icon, required this.title, required this.detail, this.action, this.actionLabel});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
    Icon(icon, size: 42), const SizedBox(height: 12),
    Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
    const SizedBox(height: 7), Text(detail, textAlign: TextAlign.center),
    if (action != null) ...[const SizedBox(height: 14), FilledButton(onPressed: action, child: Text(actionLabel!))],
  ])));
}

class _DailyStateBanner extends StatelessWidget {
  final DailyBriefState state; final String? detail;
  const _DailyStateBanner({required this.state, this.detail});
  @override Widget build(BuildContext context) {
    final (title, message) = switch (state) {
      DailyBriefState.insufficientWardrobe => ('Dressing encore réduit', 'La proposition utilise toutes les catégories disponibles. Ajoute des pièces pour obtenir une tenue plus complète.'),
      DailyBriefState.noProposal => ('Aucune proposition possible', 'Le moteur ne trouve aucune combinaison cohérente avec les pièces disponibles.'),
      DailyBriefState.weatherError => ('Météo indisponible', detail ?? 'La tenue est proposée sans contrainte météo.'),
      _ => ('', ''),
    };
    if (title.isEmpty) return const SizedBox.shrink();
    return _BriefStateMessage(icon: Icons.info_outline, title: title, detail: message);
  }
}

class _BriefLoading extends StatelessWidget {
  const _BriefLoading();
  @override
  Widget build(BuildContext context) => const Card(child: Padding(
    padding: EdgeInsets.all(24),
    child: Row(children: [
      SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
      SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text('Chargement du dressing…', style: TextStyle(fontWeight: FontWeight.w800)),
          SizedBox(height: 4), Text('La page est prête, la tenue arrive dans un instant.')]))
    ]),
  ));
}

class _BriefError extends StatelessWidget {
  final VoidCallback onRetry;
  const _BriefError({required this.onRetry});
  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(children: [
      const Icon(Icons.error_outline, size: 40), const SizedBox(height: 10),
      const Text('Impossible de préparer le Daily Brief', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6), const Text('Le chargement du dressing ou le moteur de tenue a échoué. La météo est signalée séparément.'),
      const SizedBox(height: 14), FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
    ]),
  ));
}
