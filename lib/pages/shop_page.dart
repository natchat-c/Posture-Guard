import 'package:flutter/material.dart';

import '../l10n/locale_controller.dart';
import '../models/cosmetics.dart';
import '../models/gacha_box_visual_config.dart';
import '../services/coin_repository.dart';
import '../services/cosmetic_repository.dart';
import '../services/gacha_service.dart';
import '../widgets/coach_mark_overlay.dart';
import '../widgets/cosmetic_widgets.dart';
import '../widgets/gacha_box_visual.dart';
import '../widgets/responsive_layout.dart';

enum ShopTourResult { completed, back, skipped }

class Shop extends StatefulWidget {
  const Shop({
    super.key,
    this.cosmeticStore,
    this.coinStore,
    this.gachaService,
    this.showGuidedTour = false,
  });

  final CosmeticStore? cosmeticStore;
  final CoinStore? coinStore;
  final GachaService? gachaService;
  final bool showGuidedTour;

  @override
  State<Shop> createState() => _ShopState();
}

class _ShopState extends State<Shop> {
  late final CosmeticStore _cosmeticStore;
  late final CoinStore _coinStore;
  late final GachaShopService _shopService;
  Set<String> _ownedIds = CosmeticCatalog.starterIds;
  int _coins = 0;
  bool _opening = false;
  final GlobalKey _boxesTourKey = GlobalKey();
  bool _guidedTourVisible = false;
  bool _guidedTourTargetPrepared = false;

  @override
  void initState() {
    super.initState();
    _cosmeticStore = widget.cosmeticStore ?? CosmeticRepository();
    _coinStore = widget.coinStore ?? CoinRepository();
    _shopService = GachaShopService(
      coinStore: _coinStore,
      cosmeticStore: _cosmeticStore,
      gachaService: widget.gachaService,
    );
    _guidedTourVisible = widget.showGuidedTour;
    _loadEconomy();
  }

  Future<void> _loadEconomy() async {
    try {
      final coinState = await _coinStore.load();
      final ownedIds = await _cosmeticStore.loadOwnedIds();
      if (!mounted) return;
      setState(() {
        _coins = coinState.totalCoins;
        _ownedIds = ownedIds;
      });
    } catch (error) {
      debugPrint('Could not load cosmetic economy: $error');
    }
  }

  Future<void> _openBox(GachaBoxType type) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final result = await _shopService.openBox(type);
      if (!mounted || result.status == GachaPurchaseStatus.busy) return;
      if (result.status == GachaPurchaseStatus.insufficientCoins) {
        setState(() => _coins = result.coinBalance ?? _coins);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(context.l10n.notEnoughCoins)));
        return;
      }

      final ownedIds = await _cosmeticStore.loadOwnedIds();
      if (!mounted) return;
      setState(() {
        _coins = result.coinBalance ?? _coins;
        _ownedIds = ownedIds;
      });
      await _showResult(result);
    } catch (error) {
      debugPrint('Could not open gacha box: $error');
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(context.l10n.gachaOpenFailed)));
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  CosmeticSelection _previewSelection(CosmeticItem item) {
    return CosmeticSelection.none.withCategory(item.category, item.id);
  }

  Future<void> _showResult(GachaPurchaseResult result) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.68),
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: const Duration(milliseconds: 180),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      pageBuilder: (dialogContext, animation, secondaryAnimation) =>
          GachaOpeningOverlay(
            result: result,
            visualConfig: GachaBoxVisualConfigs.finalized.forType(
              result.boxType,
            ),
            onContinue: () => Navigator.pop(dialogContext),
          ),
    );
  }

  String _boxName(BuildContext context, GachaBoxType type) => switch (type) {
    GachaBoxType.standard => context.l10n.standardBox,
    GachaBoxType.premium => context.l10n.premiumBox,
  };

  Future<void> _showOdds(GachaBoxType type) {
    final l10n = context.l10n;
    final config = GachaConfiguration.forType(type);
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: Key('oddsDialog-${type.name}'),
        title: Text(_boxName(context, type)),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.boxCost(config.cost),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 14),
                Text(
                  l10n.dropRates,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                for (final rarity in CosmeticRarity.values)
                  Row(
                    key: Key('odds-${type.name}-${rarity.name}'),
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(rarity.stars)),
                      Flexible(
                        child: Text(
                          '${config.rarityOdds[rarity]}%',
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 14),
                Text(l10n.duplicatesConvertedInfo),
                const Divider(height: 24),
                Text(
                  l10n.duplicateRewards,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                for (final rarity in CosmeticRarity.values)
                  Row(
                    key: Key('refund-${type.name}-${rarity.name}'),
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(rarity.stars)),
                      Flexible(
                        child: Text(
                          l10n.coinCount(
                            GachaConfiguration.duplicateRefund(rarity),
                          ),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            key: Key('close-${type.name}-odds'),
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  Widget _boxCard(BuildContext context, GachaBoxType type) {
    final config = GachaConfiguration.forType(type);
    return Padding(
      key: Key('gachaBox-${type.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              key: Key('gachaArtworkArea-${type.name}'),
              fit: StackFit.expand,
              children: [
                GachaBoxVisual(
                  key: Key('shopGachaBoxVisual-${type.name}'),
                  type: type,
                  config: GachaBoxVisualConfigs.finalized.forType(type),
                  keyPrefix: 'shopGachaBox',
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    key: Key('odds-help-${type.name}'),
                    tooltip: context.l10n.odds,
                    style: IconButton.styleFrom(
                      minimumSize: const Size.square(48),
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHigh
                          .withValues(alpha: 0.88),
                    ),
                    onPressed: () => _showOdds(type),
                    icon: const Icon(Icons.question_mark, size: 20),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _boxName(context, type),
            key: type == GachaBoxType.standard ? _boxesTourKey : null,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            context.l10n.coinCount(config.cost),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: Key('open-${type.name}-box'),
              onPressed: _opening || _guidedTourVisible
                  ? null
                  : () => _openBox(type),
              child: Text(context.l10n.open),
            ),
          ),
        ],
      ),
    );
  }

  Widget _boxes(BuildContext context, double width) {
    final cards = [
      Expanded(child: _boxCard(context, GachaBoxType.standard)),
      Expanded(child: _boxCard(context, GachaBoxType.premium)),
    ];
    if (width >= 560) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [cards[0], const SizedBox(width: 14), cards[1]],
      );
    }
    return Column(
      children: [
        _boxCard(context, GachaBoxType.standard),
        const Divider(height: 32),
        _boxCard(context, GachaBoxType.premium),
      ],
    );
  }

  Future<void> _prepareGuidedTourTarget() async {
    if (!_guidedTourVisible || _guidedTourTargetPrepared) return;
    _guidedTourTargetPrepared = true;
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) setState(() {});
  }

  Rect? _guidedTourTargetRect() {
    final renderObject = _boxesTourKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }

  void _finishGuidedTour(ShopTourResult result) {
    Navigator.pop(context, result);
  }

  Widget _collectionSection(
    BuildContext context, {
    required CosmeticCategory category,
    required String title,
    required int columns,
  }) {
    final locale = Localizations.localeOf(context);
    final items = CosmeticCatalog.forCategory(category);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          key: Key('shop-${category.name}-grid'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.72,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final owned = _ownedIds.contains(item.id);
            return CosmeticOptionTile(
              key: Key('shop-item-${item.id}'),
              label: item.localizedName(locale),
              previewSelection: _previewSelection(item),
              rarityLabel: item.rarity.stars,
              statusLabel: item.isStarter
                  ? context.l10n.starter
                  : owned
                  ? context.l10n.owned
                  : context.l10n.locked,
              locked: !owned,
              selected: false,
              onTap: null,
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_guidedTourVisible) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _prepareGuidedTourTarget(),
      );
    }
    final page = Scaffold(
      appBar: AppBar(title: Text(l10n.shop)),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final padding = constraints.responsiveHorizontalPadding;
            final columns = constraints.maxWidth >= 520 ? 3 : 2;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: ResponsiveBreakpoints.maxContentWidth,
                ),
                child: ListView(
                  key: const Key('shopScrollView'),
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(padding, 16, padding, 24),
                  children: [
                    Text(
                      l10n.coinsBalance(_coins),
                      key: const Key('shopCoinBalance'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _boxes(context, constraints.maxWidth),
                    const SizedBox(height: 28),
                    Text(
                      l10n.collection,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 14),
                    _collectionSection(
                      context,
                      category: CosmeticCategory.hat,
                      title: l10n.hats,
                      columns: columns,
                    ),
                    const SizedBox(height: 22),
                    _collectionSection(
                      context,
                      category: CosmeticCategory.eyewear,
                      title: l10n.eyewear,
                      columns: columns,
                    ),
                    const SizedBox(height: 22),
                    _collectionSection(
                      context,
                      category: CosmeticCategory.holding,
                      title: l10n.holding,
                      columns: columns,
                    ),
                    const SizedBox(height: 22),
                    _collectionSection(
                      context,
                      category: CosmeticCategory.back,
                      title: l10n.backAccessories,
                      columns: columns,
                    ),
                    const SizedBox(key: Key('shopContentEnd'), height: 12),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    if (!_guidedTourVisible) return page;
    return Stack(
      children: [
        page,
        Positioned.fill(
          child: CoachMarkOverlay(
            target: _guidedTourTargetRect(),
            title: l10n.shopTourTitle,
            body: l10n.shopTourBody,
            currentStep: 0,
            totalSteps: 1,
            backLabel: l10n.back,
            nextLabel: l10n.done,
            skipLabel: l10n.skipForNow,
            onBack: () => _finishGuidedTour(ShopTourResult.back),
            onNext: () => _finishGuidedTour(ShopTourResult.completed),
            onSkip: () => _finishGuidedTour(ShopTourResult.skipped),
            nextButtonKey: const Key('shopTourNextButton'),
            backButtonKey: const Key('shopTourBackButton'),
            skipButtonKey: const Key('shopTourSkipButton'),
          ),
        ),
      ],
    );
  }
}
