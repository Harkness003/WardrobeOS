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

class MainShell extends StatefulWidget {
  final AppSettings settings;
  final WeatherService weatherService;

  const MainShell({
    super.key,
    required this.settings,
    required this.weatherService,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  late final _assistantWardrobe = WardrobeController();
  late final _assistantOutfits = OutfitsController();
  late final _assistantService = AssistantService(
    contextBuilder: AssistantContextBuilder(
      weatherService: widget.weatherService,
      wardrobeController: _assistantWardrobe,
      outfitsController: _assistantOutfits,
    ),
  );

  @override
  void dispose() {
    _assistantWardrobe.dispose();
    _assistantOutfits.dispose();
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
        openWardrobe: () => goTo(1),
        openOutfits: () => goTo(2),
        openAssistant: () => goTo(3),
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
      const WardrobeScreen(),
      const OutfitsScreen(),
      AssistantScreen(service: _assistantService),
      const WishlistScreen(),
      ProfileScreen(settings: widget.settings),
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
