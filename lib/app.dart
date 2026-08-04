import 'package:flutter/material.dart';
import 'core/settings/app_settings.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/main_shell.dart';
import 'weather/api/open_meteo_api.dart';
import 'weather/location/city_search_service.dart';
import 'weather/location/geolocator_location_service.dart';
import 'weather/location/location_preferences_store.dart';
import 'weather/location/unified_location_service.dart';
import 'weather/services/cached_weather_service.dart';

class WardrobeOSApp extends StatefulWidget {
  const WardrobeOSApp({super.key});

  @override
  State<WardrobeOSApp> createState() => _WardrobeOSAppState();
}

class _WardrobeOSAppState extends State<WardrobeOSApp> {
  final settings = AppSettings();
  late final locationService = UnifiedLocationService(
    gpsService: GeolocatorLocationService(),
    preferencesStore: SecureLocationPreferencesStore(),
    citySearchService: GeocodingCitySearchService(),
  );
  late final weatherService = CachedWeatherService(
    locationService: locationService,
    weatherApi: OpenMeteoApi(),
  );

  @override
  void initState() {
    super.initState();
    settings.addListener(_refresh);
    locationService.addListener(_locationChanged);
    locationService.load();
  }

  void _locationChanged() {
    weatherService.clearCache();
    _refresh();
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    settings.removeListener(_refresh);
    locationService.removeListener(_locationChanged);
    locationService.dispose();
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
      home: MainShell(
        settings: settings,
        weatherService: weatherService,
        locationService: locationService,
      ),
    );
  }
}
