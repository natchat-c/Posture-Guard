import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'l10n/locale_controller.dart';
import 'pages/home_page.dart';
import 'pages/language_selection_page.dart';
import 'pages/privacy_notice_page.dart';
import 'pages/tutorial_page.dart';
import 'services/app_startup_coordinator.dart';
import 'services/auth_service.dart';
import 'services/camera_privacy_service.dart';
import 'services/monitoring_service.dart';
import 'services/preferences_service.dart';
import 'widgets/no_stretch_scroll_behavior.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configurePreferredOrientations();
  MonitoringService.initializeCommunicationPort();
  MonitoringService.initialize();

  runApp(const MyApp());
  unawaited(_initializeCloud());
}

@visibleForTesting
Future<void> configurePreferredOrientations() {
  return SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
}

Future<void>? _cloudInitializationInFlight;

Future<void> _initializeCloud({bool forceAuthRetry = false}) {
  final existing = _cloudInitializationInFlight;
  if (existing != null) return existing;

  late final Future<void> operation;
  operation = _initializeCloudOnce(forceAuthRetry: forceAuthRetry).whenComplete(
    () {
      if (identical(_cloudInitializationInFlight, operation)) {
        _cloudInitializationInFlight = null;
      }
    },
  );
  _cloudInitializationInFlight = operation;
  return operation;
}

Future<void> _initializeCloudOnce({required bool forceAuthRetry}) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    await AuthService.instance.ensureSignedIn(forceRetry: forceAuthRetry);
  } catch (error) {
    debugPrint('Firebase initialization skipped or failed: $error');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    this.initialTutorialCompleted,
    this.startupCoordinator,
    this.initialLanguageCode,
    this.languagePreferences,
    this.cameraPrivacyPreferences,
    @visibleForTesting this.homeBuilder,
  });

  final bool? initialTutorialCompleted;
  final AppStartupCoordinator? startupCoordinator;
  final String? initialLanguageCode;
  final LanguagePreferences? languagePreferences;
  final CameraPrivacyPreferences? cameraPrivacyPreferences;
  final Widget Function(bool showTourOnStart)? homeBuilder;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final LocaleController _localeController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _localeController = LocaleController(
      preferences: widget.languagePreferences,
      initialCode: widget.initialLanguageCode,
    )..load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _localeController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(MonitoringService.handleAppLifecycleState(state));
    if (state == AppLifecycleState.resumed) {
      unawaited(_initializeCloud(forceAuthRetry: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _localeController,
      builder: (context, _) => LocaleScope(
        controller: _localeController,
        child: MaterialApp(
          onGenerateTitle: (context) => context.l10n.appTitle,
          locale: _localeController.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color.fromARGB(255, 173, 226, 250),
            ),
          ),
          debugShowCheckedModeBanner: false,
          scrollBehavior: const NoStretchScrollBehavior(),
          home: !_localeController.isLoaded
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : _TutorialGate(
                  initialTutorialCompleted: widget.initialTutorialCompleted,
                  startupCoordinator: widget.startupCoordinator,
                  selectedLanguageCode: _localeController.selectedLanguageCode,
                  onLanguageSelected: _localeController.selectLanguage,
                  cameraPrivacyPreferences: widget.cameraPrivacyPreferences,
                  homeBuilder: widget.homeBuilder,
                ),
        ),
      ),
    );
  }
}

class _TutorialGate extends StatefulWidget {
  const _TutorialGate({
    this.initialTutorialCompleted,
    this.startupCoordinator,
    required this.selectedLanguageCode,
    required this.onLanguageSelected,
    this.cameraPrivacyPreferences,
    this.homeBuilder,
  });

  final bool? initialTutorialCompleted;
  final AppStartupCoordinator? startupCoordinator;
  final String? selectedLanguageCode;
  final Future<void> Function(String code) onLanguageSelected;
  final CameraPrivacyPreferences? cameraPrivacyPreferences;
  final Widget Function(bool showTourOnStart)? homeBuilder;

  @override
  State<_TutorialGate> createState() => _TutorialGateState();
}

class _TutorialGateState extends State<_TutorialGate> {
  AppStartupCoordinator? _coordinator;
  bool? _hasCompletedTutorial;
  bool? _privacyNoticeAcknowledged;
  bool _showInitialHomeTour = false;

  AppStartupCoordinator get _startupCoordinator {
    return _coordinator ??=
        widget.startupCoordinator ?? AppStartupCoordinator();
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialTutorialCompleted case final value?) {
      if (value) {
        _privacyNoticeAcknowledged = true;
        _restoreMonitoring();
      } else {
        _hasCompletedTutorial = false;
        _loadPrivacyState();
      }
    } else {
      _loadTutorialState();
    }
  }

  Future<void> _loadTutorialState() async {
    try {
      final completed = await _startupCoordinator.hasCompletedTutorial();
      if (!completed) {
        final acknowledged = await _privacyPreferences.isNoticeAcknowledged();
        if (mounted) {
          setState(() {
            _hasCompletedTutorial = false;
            _privacyNoticeAcknowledged = acknowledged;
          });
        }
        return;
      }
      _privacyNoticeAcknowledged = true;
      await _restoreMonitoring();
    } catch (error) {
      debugPrint('Could not load tutorial state: $error');
      if (mounted) setState(() => _hasCompletedTutorial = false);
    }
  }

  CameraPrivacyPreferences get _privacyPreferences {
    return widget.cameraPrivacyPreferences ?? CameraPrivacyPreferences();
  }

  Future<void> _loadPrivacyState() async {
    try {
      final acknowledged = await _privacyPreferences.isNoticeAcknowledged();
      if (mounted) {
        setState(() => _privacyNoticeAcknowledged = acknowledged);
      }
    } catch (error) {
      debugPrint('Could not load camera privacy state: $error');
      if (mounted) setState(() => _privacyNoticeAcknowledged = false);
    }
  }

  Future<void> _completePrivacyNotice(PrivacyNoticeChoice choice) async {
    await _privacyPreferences.acknowledgeNotice(
      useSensorsOnly: choice == PrivacyNoticeChoice.sensorsOnly,
    );
    if (mounted) setState(() => _privacyNoticeAcknowledged = true);
  }

  Future<void> _restoreMonitoring() async {
    try {
      final result = await _startupCoordinator.restoreAfterCompletedTutorial();
      if (!mounted) return;
      setState(() => _hasCompletedTutorial = true);
      _showWarning(result.warning);
    } catch (error) {
      debugPrint('Could not restore monitoring: $error');
      if (!mounted) return;
      setState(() => _hasCompletedTutorial = true);
      _showWarning(context.l10n.monitoringProblem);
    }
  }

  Future<void> _completeTutorial() async {
    try {
      final result = await _startupCoordinator.completeFirstLaunch();
      if (!mounted) return;
      setState(() {
        _hasCompletedTutorial = true;
        _showInitialHomeTour = true;
      });
      _showWarning(result.warning);
    } catch (error) {
      debugPrint('Could not complete first-run startup: $error');
      if (!mounted) return;
      setState(() => _hasCompletedTutorial = true);
      _showWarning(context.l10n.monitoringStartFailed);
    }
  }

  void _showWarning(String? warning) {
    if (warning == null || warning.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final message = warning == context.l10n.monitoringProblem
          ? warning
          : context.l10n.dataLoadWarning;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedLanguageCode == null) {
      return LanguageSelectionPage(
        onLanguageSelected: widget.onLanguageSelected,
      );
    }
    final completed = _hasCompletedTutorial;
    if (completed == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!completed) {
      final privacyAcknowledged = _privacyNoticeAcknowledged;
      if (privacyAcknowledged == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (!privacyAcknowledged) {
        return PrivacyNoticePage(onChoice: _completePrivacyNotice);
      }
      return TutorialPage(onCompleted: _completeTutorial);
    }
    return widget.homeBuilder?.call(_showInitialHomeTour) ??
        MyHomePage(showTourOnStart: _showInitialHomeTour);
  }
}
