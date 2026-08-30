import 'package:flutter/material.dart';

import '../l10n/locale_controller.dart';
import '../models/cosmetics.dart';
import '../services/coin_repository.dart';
import '../services/cosmetic_repository.dart';
import '../widgets/coach_mark_overlay.dart';
import '../widgets/cosmetic_widgets.dart';
import '../widgets/responsive_layout.dart';
import 'shop_page.dart';

enum CustomizeTourResult { completed, back, skipped }

class Customizes extends StatefulWidget {
  const Customizes({
    super.key,
    this.cosmeticStore,
    this.coinStore,
    this.showGuidedTour = false,
  });

  final CosmeticStore? cosmeticStore;
  final CoinStore? coinStore;
  final bool showGuidedTour;

  @override
  State<Customizes> createState() => _CustomizesState();
}

class _CustomizesState extends State<Customizes> {
  late final CosmeticStore _store;
  late final CoinStore _coinStore;
  CosmeticSelection _selection = CosmeticSelection.none;
  Set<String> _ownedIds = CosmeticCatalog.starterIds;
  Future<void> _saveQueue = Future<void>.value();
  final GlobalKey _ownedCosmeticsTourKey = GlobalKey();
  final GlobalKey _shopButtonTourKey = GlobalKey();
  int? _guidedTourStep;

  @override
  void initState() {
    super.initState();
    _store = widget.cosmeticStore ?? CosmeticRepository();
    _coinStore = widget.coinStore ?? CoinRepository();
    if (widget.showGuidedTour) _guidedTourStep = 0;
    _loadSelection();
  }

  Future<void> _loadSelection() async {
    try {
      final selection = await _store.load();
      final ownedIds = await _store.loadOwnedIds();
      if (!mounted) return;
      setState(() {
        _selection = selection;
        _ownedIds = ownedIds;
      });
    } catch (error) {
      debugPrint('Could not load cosmetics: $error');
    }
  }

  void _equip(CosmeticCategory category, String? id) {
    if (id != null && !_ownedIds.contains(id)) return;
    final next = _selection.withCategory(category, id);
    setState(() => _selection = next);
    _saveQueue = _saveQueue.then((_) => _store.save(next)).catchError((
      Object error,
    ) {
      debugPrint('Could not save cosmetics: $error');
    });
  }

  CosmeticSelection _previewFor(CosmeticCategory category, String? id) {
    return _selection.withCategory(category, id);
  }

  Widget _categoryRow(
    BuildContext context, {
    required CosmeticCategory category,
    required String title,
    Key? tourKey,
  }) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final items = CosmeticCatalog.forCategory(
      category,
    ).where((item) => _ownedIds.contains(item.id)).toList(growable: false);
    return KeyedSubtree(
      key: tourKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 166,
            child: ListView.separated(
              key: Key('customize-${category.name}-list'),
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              itemCount: items.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = index == 0 ? null : items[index - 1];
                final id = item?.id;
                return SizedBox(
                  width: 112,
                  child: CosmeticOptionTile(
                    key: Key('customize-${category.name}-${id ?? 'none'}'),
                    label: item?.localizedName(locale) ?? l10n.none,
                    previewSelection: _previewFor(category, id),
                    rarityLabel: item?.rarity.stars,
                    selected: _selection.idFor(category) == id,
                    onTap: _guidedTourStep == null
                        ? () => _equip(category, id)
                        : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  GlobalKey? _guidedTourTargetKey(int? step) {
    return switch (step) {
      0 => _ownedCosmeticsTourKey,
      1 => _shopButtonTourKey,
      _ => null,
    };
  }

  void _finishGuidedTour(CustomizeTourResult result) {
    Navigator.pop(context, result);
  }

  Future<void> _openShop() async {
    final guided = _guidedTourStep == 1;
    if (guided) setState(() => _guidedTourStep = null);
    final result = await Navigator.push<ShopTourResult>(
      context,
      MaterialPageRoute(
        builder: (context) => Shop(
          cosmeticStore: _store,
          coinStore: _coinStore,
          showGuidedTour: guided,
        ),
      ),
    );
    await _loadSelection();
    if (!mounted || !guided) return;
    switch (result) {
      case ShopTourResult.completed:
        _finishGuidedTour(CustomizeTourResult.completed);
      case ShopTourResult.skipped:
        _finishGuidedTour(CustomizeTourResult.skipped);
      case ShopTourResult.back:
      case null:
        setState(() => _guidedTourStep = 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final page = Scaffold(
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
                          maxWidth: constraints.isVerySmallPhone ? 230 : 300,
                        ),
                        child: CharacterPreview(
                          key: const Key('customizeCharacterArtwork'),
                          selection: _selection,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _categoryRow(
                      context,
                      category: CosmeticCategory.hat,
                      title: l10n.hats,
                      tourKey: _ownedCosmeticsTourKey,
                    ),
                    const SizedBox(height: 22),
                    _categoryRow(
                      context,
                      category: CosmeticCategory.eyewear,
                      title: l10n.eyewear,
                    ),
                    const SizedBox(height: 22),
                    _categoryRow(
                      context,
                      category: CosmeticCategory.holding,
                      title: l10n.holding,
                    ),
                    const SizedBox(height: 22),
                    _categoryRow(
                      context,
                      category: CosmeticCategory.back,
                      title: l10n.backAccessories,
                    ),
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
              key: _shopButtonTourKey,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                key: const Key('customizeBottomAction'),
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  key: const Key('customizeBuyMoreButton'),
                  onPressed: _guidedTourStep == 0 ? null : _openShop,
                  child: Text(l10n.buyMore, textAlign: TextAlign.center),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final step = _guidedTourStep;
    if (step == null) return page;
    return Stack(
      children: [
        page,
        Positioned.fill(
          child: CoachMarkOverlay(
            targetKey: _guidedTourTargetKey(step),
            targetIdentity: step,
            title: step == 0
                ? l10n.customizeTourTitle
                : l10n.customizeShopTourTitle,
            body: step == 0
                ? l10n.customizeTourBody
                : l10n.customizeShopTourBody,
            currentStep: step,
            totalSteps: 2,
            backLabel: l10n.back,
            nextLabel: l10n.next,
            skipLabel: l10n.skipForNow,
            onBack: step == 0
                ? () => _finishGuidedTour(CustomizeTourResult.back)
                : () => setState(() => _guidedTourStep = 0),
            onNext: step == 0
                ? () => setState(() => _guidedTourStep = 1)
                : null,
            onSkip: () => _finishGuidedTour(CustomizeTourResult.skipped),
            nextButtonKey: const Key('customizeTourNextButton'),
            backButtonKey: const Key('customizeTourBackButton'),
            skipButtonKey: const Key('customizeTourSkipButton'),
          ),
        ),
      ],
    );
  }
}
