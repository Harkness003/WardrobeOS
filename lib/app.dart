import 'package:flutter/material.dart';
import 'core/settings/app_settings.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/main_shell.dart';

class WardrobeOSApp extends StatefulWidget {
  const WardrobeOSApp({super.key});

  @override
  State<WardrobeOSApp> createState() => _WardrobeOSAppState();
}

class _WardrobeOSAppState extends State<WardrobeOSApp> {
  final settings = AppSettings();

  @override
  void initState() {
    super.initState();
    settings.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    settings.removeListener(_refresh);
    settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WardrobeOS',
      theme: AppTheme.light,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      home: MainShell(settings: settings),
    );
  }
}
