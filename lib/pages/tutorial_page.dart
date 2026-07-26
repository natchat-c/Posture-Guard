import 'package:flutter/material.dart';

class TutorialPage extends StatefulWidget {
  const TutorialPage({super.key, this.isReplay = false, this.onCompleted});

  final bool isReplay;
  final Future<void> Function()? onCompleted;

  @override
  State<TutorialPage> createState() => _TutorialPageState();
}

class _TutorialContent {
  const _TutorialContent({
    required this.icon,
    required this.title,
    required this.text,
    this.extra,
  });

  final IconData icon;
  final String title;
  final String text;
  final Widget? extra;
}

class _TutorialPageState extends State<TutorialPage> {
  final PageController _controller = PageController();
  int _page = 0;
  bool _finishing = false;

  late final List<_TutorialContent> _pages = [
    const _TutorialContent(
      icon: Icons.health_and_safety_outlined,
      title: 'Welcome to Posture Guard',
      text:
          'Posture Guard helps you notice when you hold your phone at an unhealthy angle.',
    ),
    const _TutorialContent(
      icon: Icons.center_focus_strong,
      title: 'Calibrate your posture',
      text:
          'Sit upright in a comfortable position and press Calibrate. This becomes your neutral phone position.',
    ),
    const _TutorialContent(
      icon: Icons.toggle_on_outlined,
      title: 'Automatic monitoring',
      text:
          'Posture Guard starts monitoring after you press Get Started. '
          'Use the master switch in Settings whenever you want to disable or enable it.',
    ),
    const _TutorialContent(
      icon: Icons.notifications_active_outlined,
      title: 'Receive posture alerts',
      text:
          'If poor posture continues for several seconds, your phone will vibrate and send a notification. Alerts will continue until your posture improves.',
    ),
    const _TutorialContent(
      icon: Icons.camera_alt_outlined,
      title: 'How the camera is used',
      text:
          'Posture Guard may use your camera while the app is open to improve posture detection. The camera is not used when the app is closed or running in the background.',
      extra: _CameraPrivacyDetails(),
    ),
    const _TutorialContent(
      icon: Icons.tune,
      title: 'Adjust your alerts',
      text:
          'Use Settings to change how long poor posture must continue before an alert and how often alerts repeat.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_page < _pages.length - 1) {
      await _controller.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      return;
    }

    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      if (widget.isReplay) {
        if (mounted) Navigator.pop(context);
      } else {
        await widget.onCompleted?.call();
      }
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;

    return Scaffold(
      appBar: widget.isReplay
          ? AppBar(title: const Text('How to use Posture Guard'))
          : null,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                key: const Key('tutorialPageView'),
                controller: _controller,
                physics: const ClampingScrollPhysics(),
                itemCount: _pages.length,
                onPageChanged: (value) => setState(() => _page = value),
                itemBuilder: (context, index) {
                  final content = _pages[index];
                  return SingleChildScrollView(
                    key: Key('tutorialPageScroll$index'),
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(28, 48, 28, 24),
                    child: Column(
                      children: [
                        Icon(
                          content.icon,
                          size: 92,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 36),
                        Text(
                          content.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          content.text,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        if (content.extra != null) ...[
                          const SizedBox(height: 24),
                          content.extra!,
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: index == _page ? 24 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: index == _page
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('tutorialNextButton'),
                  onPressed: _finishing ? null : _next,
                  child: Text(
                    isLast
                        ? (widget.isReplay ? 'Done' : 'Get Started')
                        : 'Next',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraPrivacyDetails extends StatelessWidget {
  const _CameraPrivacyDetails();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('• Camera images are used only for posture detection.'),
            SizedBox(height: 8),
            Text('• Posture Guard does not save camera images.'),
            SizedBox(height: 8),
            Text(
              '• Phone-angle monitoring still works without camera permission.',
            ),
          ],
        ),
      ),
    );
  }
}
