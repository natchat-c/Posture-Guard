import 'package:flutter/material.dart';

import '../l10n/locale_controller.dart';
import '../widgets/responsive_layout.dart';
import 'shop_page.dart';

class Customizes extends StatelessWidget {
  const Customizes({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.customize)),
      body: SafeArea(
        top: false,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final padding = constraints.responsiveHorizontalPadding;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: ResponsiveBreakpoints.maxContentWidth,
                ),
                child: ListView(
                  key: const Key('customizeScrollView'),
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(padding, 16, padding, 24),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.isVerySmallPhone ? 250 : 340,
                        ),
                        child: AspectRatio(
                          key: const Key('customizeCharacterArtwork'),
                          aspectRatio: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: Image.asset(
                              'images/happy slime.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(thickness: 2),
                    const SizedBox(key: Key('customizeContentEnd'), height: 12),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: ResponsiveBreakpoints.maxContentWidth,
            ),
            child: Padding(
              key: const Key('customizeBottomAction'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  key: const Key('customizeBuyMoreButton'),
                  onPressed: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute(builder: (context) => const Shop()),
                    );
                  },
                  child: Text(l10n.buyMore, textAlign: TextAlign.center),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
