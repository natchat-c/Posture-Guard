import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'l10n/locale_controller.dart';
import 'pages/home_page.dart';
import 'pages/language_selection_page.dart';
import 'pages/tutorial_page.dart';
import 'services/app_startup_coordinator.dart';
import 'services/monitoring_service.dart';
import 'services/preferences_service.dart';
import 'widgets/no_stretch_scroll_behavior.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  MonitoringService.initialize();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization skipped or failed: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    this.initialTutorialCompleted,
    this.startupCoordinator,
    this.initialLanguageCode,
    this.languagePreferences,
  });

  final bool? initialTutorialCompleted;
  final AppStartupCoordinator? startupCoordinator;
  final String? initialLanguageCode;
  final LanguagePreferences? languagePreferences;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final LocaleController _localeController;

  @override
  void initState() {
    super.initState();
    _localeController = LocaleController(
      preferences: widget.languagePreferences,
      initialCode: widget.initialLanguageCode,
    )..load();
  }

  @override
  void dispose() {
    _localeController.dispose();
    super.dispose();
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
  });

  final bool? initialTutorialCompleted;
  final AppStartupCoordinator? startupCoordinator;
  final String? selectedLanguageCode;
  final Future<void> Function(String code) onLanguageSelected;

  @override
  State<_TutorialGate> createState() => _TutorialGateState();
}

class _TutorialGateState extends State<_TutorialGate> {
  AppStartupCoordinator? _coordinator;
  bool? _hasCompletedTutorial;
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
        _restoreMonitoring();
      } else {
        _hasCompletedTutorial = false;
      }
    } else {
      _loadTutorialState();
    }
  }

  Future<void> _loadTutorialState() async {
    try {
      final completed = await _startupCoordinator.hasCompletedTutorial();
      if (!completed) {
        if (mounted) setState(() => _hasCompletedTutorial = false);
        return;
      }
      await _restoreMonitoring();
    } catch (error) {
      debugPrint('Could not load tutorial state: $error');
      if (mounted) setState(() => _hasCompletedTutorial = false);
    }
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
      return TutorialPage(onCompleted: _completeTutorial);
    }
    return MyHomePage(showTourOnStart: _showInitialHomeTour);
  }
}
