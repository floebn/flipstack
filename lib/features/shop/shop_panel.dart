import 'package:flutter/material.dart';

import '../../game/flipstack_game.dart';
import '../../game/meta/rewards.dart';
import '../../game/render/looks.dart';
import '../../services/storage/profile_store.dart';
import '../../shared/theme/fs_colors.dart';
import '../../shared/widgets/fs_widgets.dart';
import '../rewards/rewards_ui.dart';

const _name = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w700,
  color: FsColors.navy,
);
const _mintText = Color(0xFF1F8A7B);

/// Färbt das graue Vorschaubild eines Materials in Mint (Grauwert 200).
const _mintTint = ColorFilter.matrix(<double>[
  0.265, 0, 0, 0, 0, //
  0, 0.91, 0, 0, 0, //
  0, 0, 0.82, 0, 0, //
  0, 0, 0, 1, 0, //
]);

/// Reihenfolge und Namen der Reiter (Masterbrief, Abschnitt Shop).
const _tabs = [
  (CosmeticCategory.platform, 'Plattformen'),
  (CosmeticCategory.blocks, 'Blöcke'),
  (CosmeticCategory.background, 'Hintergründe'),
  (CosmeticCategory.effect, 'Effekte'),
];

/// Kategorien je Reiter. Unter "Blöcke" stehen Material und Farben
/// untereinander; beides lässt sich frei kombinieren.
const _sections = {
  CosmeticCategory.platform: [(CosmeticCategory.platform, '')],
  CosmeticCategory.blocks: [
    (CosmeticCategory.material, 'MATERIAL'),
    (CosmeticCategory.blocks, 'FARBEN'),
  ],
  CosmeticCategory.background: [(CosmeticCategory.background, '')],
  CosmeticCategory.effect: [(CosmeticCategory.effect, '')],
};

/// Shop als Tafel in der unteren Bildschirmhälfte. Darüber bleibt der
/// Beispielturm des Spiels sichtbar und dient als Bühne: Ein angetipptes Stück
/// wird dort sofort gezeigt, auch wenn es noch nicht gekauft ist.
class ShopPanel extends StatefulWidget {
  const ShopPanel({
    super.key,
    required this.controller,
    required this.game,
    required this.onClose,
    required this.onTap,
  });
  final ProfileController controller;
  final FlipstackGame game;
  final VoidCallback onClose, onTap;

  @override
  State<ShopPanel> createState() => _ShopPanelState();
}

class _ShopPanelState extends State<ShopPanel> {
  CosmeticCategory _tab = _tabs.first.$1;

  /// Je Kategorie das gerade angesehene Stück (Anprobe).
  final Map<CosmeticCategory, String> _viewing = {};

  @override
  void initState() {
    super.initState();
    widget.game.shopStage = true;
  }

  @override
  void dispose() {
    widget.game
      ..shopStage = false
      ..previewLook(const {});
    super.dispose();
  }

  /// Je Reiter das zuletzt angetippte Stück; darauf bezieht sich der Knopf.
  final Map<CosmeticCategory, String> _focus = {};

  Cosmetic _current(Profile p) =>
      Cosmetics.byId[_focus[_tab]] ?? p.equippedIn(_sections[_tab]!.first.$1);

  void _view(Cosmetic item) {
    widget.onTap();
    setState(() {
      _viewing[item.category] = item.id;
      _focus[_tab] = item.id;
    });
    widget.game.previewLook(_viewing);
    if (item.category == CosmeticCategory.effect) widget.game.previewEffect();
  }

  Future<void> _act(Profile p, Cosmetic item) async {
    widget.onTap();
    if (p.owns(item.id)) {
      widget.controller.equip(item.id);
      return;
    }
    if (p.coins < item.price) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FsColors.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('${item.name} freischalten?', style: _name),
        content: Text(
          'Das kostet ${item.price} Münzen. Danach hast du noch '
          '${p.coins - item.price}.',
          style: _name.copyWith(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Abbrechen',
              style: _name.copyWith(fontSize: 15, color: FsColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Freischalten',
              style: _name.copyWith(fontSize: 15, color: _mintText),
            ),
          ),
        ],
      ),
    );
    if (ok == true) widget.controller.buy(item.id);
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final p = widget.controller.profile;
        final current = _current(p);
        // Alles, was der Turm gerade trägt, ohne dass es gekauft ist
        final trying = [
          for (final id in _viewing.values)
            if (!p.owns(id)) Cosmetics.byId[id]!.name,
        ];
        return Stack(
          children: [
            // Oben: Kontostand, Schliessen und der Name des angesehenen Stücks
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CoinBadge(p.coins),
                    const Spacer(),
                    RoundIconButton(
                      Icons.close_rounded,
                      onTap: widget.onClose,
                      size: 46,
                      color: FsColors.cream,
                      iconColor: FsColors.navy,
                      semanticLabel: 'Shop schließen',
                    ),
                  ],
                ),
              ),
            ),
            if (trying.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: height * 0.60 + 14,
                child: Center(
                  child: FsChip(
                    'Anprobe: ${trying.join(', ')}',
                    color: FsColors.navy,
                  ),
                ),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 1, end: 0),
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                builder: (context, t, child) => Transform.translate(
                  offset: Offset(0, t * height * 0.6),
                  child: child,
                ),
                child: Container(
                  height: height * 0.60,
                  decoration: const BoxDecoration(
                    color: FsColors.cream,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x33202B38),
                        blurRadius: 30,
                        offset: Offset(0, -6),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                          child: _Tabs(
                            selected: _tab,
                            onSelect: (c) {
                              widget.onTap();
                              setState(() => _tab = c);
                            },
                          ),
                        ),
                        Expanded(
                          child: CustomScrollView(
                            key: ValueKey(_tab),
                            slivers: [
                              for (final (category, title)
                                  in _sections[_tab]!) ...[
                                if (title.isNotEmpty)
                                  SliverPadding(
                                    padding: const EdgeInsets.fromLTRB(
                                      22,
                                      2,
                                      16,
                                      8,
                                    ),
                                    sliver: SliverToBoxAdapter(
                                      child: Text(title, style: fsLabel),
                                    ),
                                  ),
                                SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    14,
                                  ),
                                  sliver: SliverGrid.count(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: 1.12,
                                    children: [
                                      for (final item in Cosmetics.of(category))
                                        _Card(
                                          item: item,
                                          profile: p,
                                          viewing: item.id == current.id,
                                          onTap: () => _view(item),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                          child: _Action(
                            item: current,
                            profile: p,
                            onTap: () => _act(p, current),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected, required this.onSelect});
  final CosmeticCategory selected;
  final ValueChanged<CosmeticCategory> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0x12202B38),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          for (final (category, label) in _tabs)
            Expanded(
              flex: label.length + 6,
              child: Semantics(
                button: true,
                selected: category == selected,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelect(category),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: category == selected
                          ? FsColors.navy
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: category == selected
                            ? Colors.white
                            : FsColors.navy,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Karte eines Stücks: Vorschau, Name, Preis oder Besitz.
class _Card extends StatelessWidget {
  const _Card({
    required this.item,
    required this.profile,
    required this.viewing,
    required this.onTap,
  });
  final Cosmetic item;
  final Profile profile;
  final bool viewing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final owned = profile.owns(item.id);
    final equipped = profile.equippedIn(item.category).id == item.id;
    final affordable = profile.coins >= item.price;
    final Widget status = equipped
        ? Text(
            'Ausgewählt',
            style: _name.copyWith(fontSize: 13, color: _mintText),
          )
        : owned
        ? Text(
            'Im Besitz',
            style: _name.copyWith(fontSize: 13, color: FsColors.textMuted),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CoinIcon(size: 18),
              const SizedBox(width: 4),
              Text(
                '${item.price}',
                style: _name.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: affordable ? FsColors.navy : FsColors.textMuted,
                ),
              ),
            ],
          );
    return Semantics(
      button: true,
      selected: viewing,
      label: item.name,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: viewing ? 0.95 : 0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: viewing ? FsColors.navy : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: _Preview(item),
                    ),
                    if (equipped)
                      const Positioned(
                        right: 6,
                        top: 6,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: FsColors.action,
                            size: 22,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 8, 6, 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _name,
                    ),
                    const SizedBox(height: 1),
                    SizedBox(height: 20, child: status),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Der eine Knopf unter dem Raster: was mit dem angesehenen Stück geht.
class _Action extends StatelessWidget {
  const _Action({
    required this.item,
    required this.profile,
    required this.onTap,
  });
  final Cosmetic item;
  final Profile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final equipped = profile.equippedIn(item.category).id == item.id;
    final owned = profile.owns(item.id);
    final missing = item.price - profile.coins;
    final (label, enabled) = equipped
        ? ('AUSGEWÄHLT', false)
        : owned
        ? ('AUSWÄHLEN', true)
        : missing > 0
        ? ('ES FEHLEN $missing MÜNZEN', false)
        : ('FREISCHALTEN  ·  ${item.price}', true);
    return IgnorePointer(
      ignoring: !enabled,
      child: PillButton(label, onTap: onTap, enabled: enabled, height: 56),
    );
  }
}

/// Kleine Vorschau einer Freischaltung auf der Karte.
class _Preview extends StatelessWidget {
  const _Preview(this.item);
  final Cosmetic item;

  @override
  Widget build(BuildContext context) {
    switch (item.category) {
      case CosmeticCategory.material:
        final name = item.id.substring(4); // mat_pebble -> pebble
        return ColoredBox(
          color: const Color(0x0F202B38),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColorFiltered(
                  colorFilter: _mintTint,
                  child: Image.asset(
                    'assets/ui/mat_$name.png',
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                if (Looks.material(item.id).$2 != null)
                  Image.asset(
                    'assets/ui/mat_${name}_gloss.png',
                    filterQuality: FilterQuality.medium,
                  ),
              ],
            ),
          ),
        );
      case CosmeticCategory.blocks:
        final colors = Looks.palette(item.id);
        return Column(
          children: [
            for (var row = 0; row < 2; row++)
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < 4; i++)
                      Expanded(child: ColoredBox(color: colors[row * 4 + i])),
                  ],
                ),
              ),
          ],
        );
      case CosmeticCategory.background:
        final t = Looks.background(item.id);
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [t.top, t.bottom],
            ),
          ),
          child: t.scene != null
              ? Image.asset(
                  'assets/backgrounds/${t.scene}',
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, 0.1),
                  filterQuality: FilterQuality.medium,
                )
              : Align(
                  alignment: const Alignment(0.6, 0.2),
                  child: Transform.rotate(
                    angle: 0.785,
                    child: Container(
                      width: 30,
                      height: 30,
                      color: t.shape.withValues(alpha: 0.45),
                    ),
                  ),
                ),
        );
      case CosmeticCategory.platform:
        return ColoredBox(
          color: const Color(0x0F202B38),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Image.asset(
              Looks.platformPreview(item.id),
              filterQuality: FilterQuality.medium,
            ),
          ),
        );
      case CosmeticCategory.effect:
        final confetti = item.id != 'fx_dust';
        final shards = item.id == 'fx_shards';
        return ColoredBox(
          color: const Color(0xFFD9CDB8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < 6; i++)
                Container(
                  width: 7.0 + (i % 3) * 3,
                  height: 7.0 + (i % 3) * 3,
                  decoration: BoxDecoration(
                    shape: shards ? BoxShape.rectangle : BoxShape.circle,
                    color: confetti
                        ? FsColors.blocks[(i * 3) % 8]
                        : const Color(0xFFFFFAF0),
                  ),
                ),
            ],
          ),
        );
    }
  }
}
