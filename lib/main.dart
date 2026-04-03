import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';
import 'package:dio/dio.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'config/app_theme.dart';
import 'config/navigation.dart';
import 'config/constants.dart';
import 'providers/app_mode_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/blind_mode_provider.dart';
import 'providers/family_blind_provider.dart';
import 'services/auth_api_service.dart';
import 'services/blind_link_api_service.dart';
import 'services/location_service.dart';
import 'services/secure_storage_service.dart';
import 'interceptors/auth_interceptor.dart';
import 'screens/blind_link_screen.dart';
import 'screens/blind_home_screen.dart';
import 'screens/family_profile_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/mode_selection_screen.dart';
import 'screens/splash_screen.dart';

late final Dio apiDio;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = SecureStorageService();

  // Create a separate Dio instance for authenticated API calls
  apiDio = Dio(
    BaseOptions(
      baseUrl: AppConstants.backendBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  final authApi = AuthApiService(protectedDio: apiDio);
  final blindApi = BlindLinkApiService(protectedDio: apiDio);

  final authProvider = AuthProvider(authApi: authApi, storage: storage);
  final appModeProvider = AppModeProvider(storage: storage);
  final blindModeProvider = BlindModeProvider(
    blindApi: blindApi,
    storage: storage,
    locationService: LocationService(),
  );
  final familyBlindProvider = FamilyBlindProvider(blindApi: blindApi);

  apiDio.interceptors.add(
    AuthInterceptor(
      storage: storage,
      authApi: authApi,
      onAuthFailure: () => authProvider.forceUnauthenticated(),
      dio: apiDio,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: appModeProvider),
        ChangeNotifierProvider.value(value: blindModeProvider),
        ChangeNotifierProvider.value(value: familyBlindProvider),
      ],
      child: const GlobiApp(),
    ),
  );
}

class GlobiApp extends StatefulWidget {
  const GlobiApp({super.key});

  @override
  State<GlobiApp> createState() => _GlobiAppState();
}

class _GlobiAppState extends State<GlobiApp> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;
  VoidCallback? _appModeListener;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _initDeepLinks();
    _initializeApp();
  }

  void _initializeApp() {
    final appMode = context.read<AppModeProvider>();
    final auth = context.read<AuthProvider>();
    final blindMode = context.read<BlindModeProvider>();

    appMode.initialize().then((_) {
      _syncProvidersWithMode(appMode, auth, blindMode);
    });

    _appModeListener = () {
      _syncProvidersWithMode(appMode, auth, blindMode);
    };
    appMode.addListener(_appModeListener!);
  }

  void _syncProvidersWithMode(
    AppModeProvider appMode,
    AuthProvider auth,
    BlindModeProvider blindMode,
  ) {
    if (appMode.requiresAuth) {
      blindMode.stopForegroundTracking();
      auth.initialize();
      return;
    }

    if (appMode.isBlindMode) {
      blindMode.initialize();
      if (auth.isAuthenticated || auth.status != AuthStatus.unauthenticated) {
        auth.forceUnauthenticated();
      }
      return;
    }

    blindMode.stopForegroundTracking();

    if (auth.isAuthenticated || auth.status != AuthStatus.unauthenticated) {
      auth.forceUnauthenticated();
    }
  }

  void _initDeepLinks() {
    // Handle link when app is started from a deep link
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri);
    });

    // Handle links while app is running
    _linkSub = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    final isExpectedCallback =
        uri.scheme == AppConstants.redirectScheme &&
        uri.host == AppConstants.redirectHost;

    if (isExpectedCallback) {
      final appMode = context.read<AppModeProvider>();
      if (!appMode.requiresAuth) {
        return;
      }

      final auth = context.read<AuthProvider>();
      auth.handleCallback(uri);
    }
  }

  @override
  void dispose() {
    final appMode = context.read<AppModeProvider>();
    if (_appModeListener != null) {
      appMode.removeListener(_appModeListener!);
    }
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const fallbackSeed = Color(0xFF4285F4);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final lightScheme =
            lightDynamic ??
            ColorScheme.fromSeed(
              seedColor: fallbackSeed,
              brightness: Brightness.light,
            );
        final darkScheme =
            darkDynamic ??
            ColorScheme.fromSeed(
              seedColor: fallbackSeed,
              brightness: Brightness.dark,
            );

        return MaterialApp(
          title: 'Globi',
          debugShowCheckedModeBanner: false,
          navigatorObservers: [appRouteObserver],
          theme: AppTheme.lightTheme(lightScheme),
          darkTheme: AppTheme.darkTheme(darkScheme),
          home: Consumer3<AppModeProvider, AuthProvider, BlindModeProvider>(
            builder: (context, appMode, auth, blindMode, _) {
              switch (appMode.mode) {
                case AppMode.unknown:
                  return const SplashScreen();
                case AppMode.unselected:
                  return const ModeSelectionScreen();
                case AppMode.blind:
                  switch (blindMode.status) {
                    case BlindSessionStatus.unknown:
                      return const SplashScreen();
                    case BlindSessionStatus.unlinked:
                    case BlindSessionStatus.restoreFailed:
                      return const BlindLinkScreen();
                    case BlindSessionStatus.linked:
                      return const BlindHomeScreen();
                  }
                case AppMode.family:
                  switch (auth.status) {
                    case AuthStatus.unknown:
                      return const SplashScreen();
                    case AuthStatus.unauthenticated:
                      return const LoginScreen();
                    case AuthStatus.authenticated:
                      switch (auth.familyProfileStatus) {
                        case FamilyProfileStatus.unknown:
                        case FamilyProfileStatus.loading:
                          return const SplashScreen();
                        case FamilyProfileStatus.incomplete:
                        case FamilyProfileStatus.error:
                          return const FamilyProfileScreen();
                        case FamilyProfileStatus.complete:
                          return const HomeScreen();
                      }
                  }
              }
            },
          ),
        );
      },
    );
  }
}
