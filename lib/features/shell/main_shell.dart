import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/settings/app_settings.dart';
import '../assistant/assistant_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../outfits/outfits_screen.dart';
import '../outfits/outfits_controller.dart';
import '../profile/profile_screen.dart';
import '../scanner/scanner_screen.dart';
import '../wardrobe/wardrobe_screen.dart';
import '../wardrobe/wardrobe_controller.dart';
import '../wishlist/wishlist_screen.dart';
import '../../weather/services/weather_service.dart';
import '../assistant/context/assistant_context_builder.dart';
import '../assistant/services/assistant_service.dart';
import '../assistant/ai/openai_provider.dart';
import '../assistant/settings/ai_settings_controller.dart';
import '../assistant/settings/api_key_storage.dart';
import '../assistant/tools/assistant_tool_context_builder.dart';
import '../assistant/tools/weather_tool.dart';
import '../assistant/recommendation/outfit_candidate.dart';
import '../assistant/recommendation/outfit_recommendation_engine.dart';
import '../assistant/memory/database_memory_repository.dart';
import '../assistant/memory/memory_service.dart';
import '../calendar/calendar_context_builder.dart';
import '../calendar/fake_calendar_service.dart';
import '../../data/database_service.dart';
import '../backup/backup_controller.dart';
import '../backup/backup_service.dart';
import '../backup/restore_service.dart';
import '../daily_brief/daily_brief_service.dart';
import '../agenda/agenda_controller.dart';
import '../agenda/agenda_screen.dart';
import '../agenda/agenda_service.dart';
import '../assistant/tools/agenda_tool.dart';
import '../../core/ai_context/wardrobe_ai_context_service.dart';
import '../../weather/location/unified_location_service.dart';
import '../scanner/ai/openai_garment_vision_analyzer.dart';
import '../wardrobe/reanalysis/database_garment_reanalysis_repository.dart';
import '../wardrobe/reanalysis/garment_reanalysis_models.dart';
import '../wardrobe/reanalysis/garment_reanalysis_service.dart';

class MainShell extends StatefulWidget {
  final AppSettings settings;
  final WeatherService weatherService;
  final UnifiedLocationService locationService;

  const MainShell({
    super.key,
    required this.settings,
    required this.weatherService,
    required this.locationService,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  late final _assistantWardrobe = WardrobeController();
  late final _assistantOutfits = OutfitsController();
  late final _apiKeyStorage = ApiKeyStorage();
  late final _openAiProvider = OpenAiProvider(apiKeyStorage: _apiKeyStorage);
  late final _aiSettings = AiSettingsController(
    storage: _apiKeyStorage,
    provider: _openAiProvider,
  )..load();
  late final _reanalysisAnalyzer = OpenAiGarmentVisionAnalyzer(apiKeyStorage: _apiKeyStorage);
  late final _reanalysisRepository = DatabaseGarmentReanalysisRepository(DatabaseService.instance);
  late final _reanalysisService = GarmentReanalysisService(
    repository: _reanalysisRepository,
    analyzer: _reanalysisAnalyzer,
    loadPhoto: (path) => File(path).readAsBytes(),
    versions: const GarmentReanalysisVersions(
      aiModel: 'scanner-v1',
      pipeline: 'scanner-pipeline-v1',
      styleTaxonomy: '1',
      thermalEngine: '1',
    ),
  );
  late final _backupRepository = DatabaseBackupRepository(
    DatabaseService.instance,
  );
  late final _memoryService = MemoryService(
    repository: DatabaseMemoryRepository(DatabaseService.instance),
  );
  late final _agendaCalendar = FakeCalendarService();
  late final _aiContextService = WardrobeAiContextService(
    loadCurrentGarments: DatabaseService.instance.getGarments,
    memoryService: _memoryService,
  );
  late final _agendaService = AgendaService(
    database: DatabaseService.instance,
    calendarService: _agendaCalendar,
    weatherService: widget.weatherService,
    aiContextService: _aiContextService,
  );
  late final _backupController = BackupController(
    backupService: BackupService(repository: _backupRepository),
    restoreService: RestoreService(repository: _backupRepository),
  );
  late final _assistantService = AssistantService(
    contextBuilder: AssistantContextBuilder(
      weatherService: widget.weatherService,
      wardrobeController: _assistantWardrobe,
      outfitsController: _assistantOutfits,
      calendarContextBuilder: CalendarContextBuilder(
        service: FakeCalendarService(),
      ),
      memoryService: _memoryService,
      aiContextService: _aiContextService,
    ),
    toolContextBuilder: AssistantToolContextBuilder(
      tools: [
        WeatherTool(weatherService: widget.weatherService),
        AgendaTool(service: _agendaService),
      ],
    ),
    llmProvider: _openAiProvider,
    recommendationEngine: OutfitRecommendationEngine(
      candidateSource:
          () async => (await _aiContextService.build()).garments
              .map(OutfitCandidate.fromGarment)
              .toList(growable: false),
    ),
  );
  late final _dailyBriefService = DailyBriefService(
    weatherService: widget.weatherService,
    memoryService: _memoryService,
    assistantService: _assistantService,
    aiContextService: _aiContextService,
  );
  late final _agendaController = AgendaController(
    service: _agendaService,
  );

  @override
  void dispose() {
    _assistantWardrobe.dispose();
    _assistantOutfits.dispose();
    _aiSettings.dispose();
    _backupController.dispose();
    _agendaController.dispose();
    _reanalysisAnalyzer.close();
    super.dispose();
  }

  void goTo(int newIndex) {
    if (newIndex == index) return;
    setState(() => index = newIndex);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(
        weatherService: widget.weatherService,
        dailyBriefService: _dailyBriefService,
        openWardrobe: () => goTo(1),
        openOutfits: () => goTo(2),
        openAssistant: () => goTo(4),
        openScanner: () async {
          final added = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const ScannerScreen()),
          );
          if (added == true && mounted) {
            goTo(1);
          }
        },
      ),
      WardrobeScreen(reanalysisService: _reanalysisService),
      const OutfitsScreen(),
      AgendaScreen(controller: _agendaController, outfitsController: _assistantOutfits),
      AssistantScreen(service: _assistantService),
      const WishlistScreen(),
      ProfileScreen(
        settings: widget.settings,
        locationService: widget.locationService,
        aiSettings: _aiSettings,
        backupController: _backupController,
      ),
    ];

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(.02, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(key: ValueKey(index), child: pages[index]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: goTo,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.checkroom_outlined),
            selectedIcon: Icon(Icons.checkroom),
            label: 'Dressing',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Tenues',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Agenda',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'IA',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Wishlist',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
