import 'package:flutter/material.dart';

import '../models/cosmetics.dart';
import 'slime_character.dart';

class CharacterPreview extends StatelessWidget {
  const CharacterPreview({
    super.key,
    required this.selection,
    this.expression = SlimeExpression.happy,
  });

  final CosmeticSelection selection;
  final SlimeExpression expression;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: SlimeCharacter(expression: expression, selection: selection),
      ),
    );
  }
}

class CosmeticOptionTile extends StatelessWidget {
  const CosmeticOptionTile({
    super.key,
    required this.label,
    required this.previewSelection,
    required this.selected,
    required this.onTap,
    this.rarityLabel,
    this.statusLabel,
    this.locked = false,
  });

  final String label;
  final CosmeticSelection previewSelection;
  final bool selected;
  final VoidCallback? onTap;
  final String? rarityLabel;
  final String? statusLabel;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      enabled: !locked,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? colors.primaryContainer : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected ? colors.primary : Colors.transparent,
            width: 2.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Opacity(
                        opacity: locked ? 0.48 : 1,
                        child: SlimeCharacter(selection: previewSelection),
                      ),
                      if (locked)
                        const Align(
                          alignment: Alignment.topLeft,
                          child: Icon(Icons.lock, size: 22),
                        ),
                      if (selected)
                        const Align(
                          alignment: Alignment.topRight,
                          child: Icon(Icons.check_circle, size: 22),
                        ),
                    ],
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (rarityLabel != null)
                  Text(
                    rarityLabel!,
                    maxLines: 1,
                    style: TextStyle(
                      color: colors.tertiary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (statusLabel != null)
                  Text(
                    statusLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: locked ? colors.error : colors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
