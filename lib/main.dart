import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'firebase_options.dart';
import 'pages/home_page.dart';
import 'pages/tutorial_page.dart';
import 'services/app_startup_coordinator.dart';
import 'services/monitoring_service.dart';
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

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    this.initialTutorialCompleted,
    this.startupCoordinator,
  });

  final bool? initialTutorialCompleted;
  final AppStartupCoordinator? startupCoordinator;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Posture Guard',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 173, 226, 250),
        ),
      ),
      debugShowCheckedModeBanner: false,
      scrollBehavior: const NoStretchScrollBehavior(),
      home: _TutorialGate(
        initialTutorialCompleted: initialTutorialCompleted,
        startupCoordinator: startupCoordinator,
      ),
    );
  }
}

class _TutorialGate extends StatefulWidget {
  const _TutorialGate({this.initialTutorialCompleted, this.startupCoordinator});

  final bool? initialTutorialCompleted;
  final AppStartupCoordinator? startupCoordinator;

  @override
  State<_TutorialGate> createState() => _TutorialGateState();
}

class _TutorialGateState extends State<_TutorialGate> {
  AppStartupCoordinator? _coordinator;
  bool? _hasCompletedTutorial;

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
      _showWarning(
        'Posture Guard could not restore monitoring. Open Settings to try again.',
      );
    }
  }

  Future<void> _completeTutorial() async {
    try {
      final result = await _startupCoordinator.completeFirstLaunch();
      if (!mounted) return;
      setState(() => _hasCompletedTutorial = true);
      _showWarning(result.warning);
    } catch (error) {
      debugPrint('Could not complete first-run startup: $error');
      if (!mounted) return;
      setState(() => _hasCompletedTutorial = true);
      _showWarning(
        'Setup was saved, but monitoring could not start. Open Settings to try again.',
      );
    }
  }

  void _showWarning(String? warning) {
    if (warning == null || warning.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(warning)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final completed = _hasCompletedTutorial;
    if (completed == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!completed) {
      return TutorialPage(onCompleted: _completeTutorial);
    }
    return const MyHomePage();
  }
}
