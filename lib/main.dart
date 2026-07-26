import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'firebase_options.dart';
import 'pages/home_page.dart';
import 'pages/tutorial_page.dart';
import 'services/monitoring_service.dart';
import 'services/preferences_service.dart';

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
  const MyApp({super.key, this.initialTutorialCompleted});

  final bool? initialTutorialCompleted;

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
      home: _TutorialGate(initialTutorialCompleted: initialTutorialCompleted),
    );
  }
}

class _TutorialGate extends StatefulWidget {
  const _TutorialGate({this.initialTutorialCompleted});

  final bool? initialTutorialCompleted;

  @override
  State<_TutorialGate> createState() => _TutorialGateState();
}

class _TutorialGateState extends State<_TutorialGate> {
  TutorialPreferences? _preferences;
  bool? _hasCompletedTutorial;

  TutorialPreferences get _tutorialPreferences {
    return _preferences ??= TutorialPreferences();
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialTutorialCompleted case final value?) {
      _hasCompletedTutorial = value;
    } else {
      _loadTutorialState();
    }
  }

  Future<void> _loadTutorialState() async {
    try {
      final completed = await _tutorialPreferences.hasCompletedTutorial();
      if (mounted) setState(() => _hasCompletedTutorial = completed);
    } catch (error) {
      debugPrint('Could not load tutorial state: $error');
      if (mounted) setState(() => _hasCompletedTutorial = false);
    }
  }

  Future<void> _completeTutorial() async {
    await _tutorialPreferences.markCompleted();
    try {
      await MonitoringService.requestNotificationPermissionIfAppropriate();
    } catch (error) {
      debugPrint('Notification permission request failed: $error');
    }
    if (mounted) setState(() => _hasCompletedTutorial = true);
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
