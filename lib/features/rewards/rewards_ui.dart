import 'package:flutter/material.dart';

import '../../game/meta/rewards.dart';
import '../../game/render/looks.dart';
import '../../services/storage/profile_store.dart';
import '../../shared/theme/fs_colors.dart';
import '../../shared/widgets/fs_widgets.dart';

const _body = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w600,
  color: FsColors.navy,
);

/// Münzsymbol: bernsteinfarbene Scheibe mit hellem Kern.
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 16});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: FsColors.reward,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFD99C2B), width: size * 0.12),
      ),
    );
  }
}

/// Kontostand als Plakette (Hauptmenü, Shop).
class CoinBadge extends StatelessWidget {
  const CoinBadge(this.coins, {super.key});
  final int coins;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$coins Münzen',
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
        decoration: BoxDecoration(
          color: FsColors.cream,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22202B38),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CoinIcon(size: 18),
            const SizedBox(width: 8),
            Text(
              '$coins',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: FsColors.navy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Reward extends StatelessWidget {
  const _Reward(this.amount, {this.muted = false});
  final int amount;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '+$amount',
          style: _body.copyWith(
            fontWeight: FontWeight.w800,
            color: muted ? FsColors.textMuted : FsColors.navy,
          ),
        ),
        const SizedBox(width: 5),
        const CoinIcon(size: 13),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar(this.value, {this.color = FsColors.action});
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: 7,
        backgroundColor: const Color(0x1A202B38),
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
  }
}

Future<void> _sheet(
  BuildContext context,
  Listenable listenable,
  List<Widget> Function(BuildContext) children,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: FsColors.cream,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (context) => ListenableBuilder(
      listenable: listenable,
      builder: (context, _) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            children: children(context),
          ),
        ),
      ),
    ),
  );
}

// ------------------------------------------------------------------ Aufgaben

/// Tagesaufgaben, Wochenaufgaben und Erfolge als Blatt von unten.
Future<void> showQuestsSheet(BuildContext context, ProfileController ctl) {
  ctl.refresh();
  return _sheet(context, ctl, (context) {
    final p = ctl.profile;
    final open = [
      for (final a in Achievements.all)
        if (!p.achievements.contains(a.id)) a,
    ];
    final done = [
      for (final a in Achievements.all)
        if (p.achievements.contains(a.id)) a,
    ];
    return [
      const Text('HEUTE', style: fsLabel),
      for (final q in p.daily) _QuestRow(q),
      const SizedBox(height: 16),
      const Text('DIESE WOCHE', style: fsLabel),
      for (final q in p.weekly) _QuestRow(q),
      const SizedBox(height: 16),
      Text(
        'ERFOLGE  ${done.length}/${Achievements.all.length}',
        style: fsLabel,
      ),
      for (final a in [...open, ...done])
        _ProgressRow(
          title: a.title,
          text: a.text,
          progress: p.counter(a.counter),
          target: a.target,
          reward: a.reward,
          done: p.achievements.contains(a.id),
        ),
      const SizedBox(height: 8),
      Text(
        'Belohnungen werden am Ende der Runde automatisch gutgeschrieben.',
        style: _body.copyWith(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: FsColors.textMuted,
        ),
      ),
    ];
  });
}

class _QuestRow extends StatelessWidget {
  const _QuestRow(this.state);
  final QuestState state;

  @override
  Widget build(BuildContext context) {
    final q = Quests.byId[state.id]!;
    return _ProgressRow(
      title: q.text,
      progress: state.progress,
      target: q.target,
      reward: q.reward,
      done: state.done,
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.title,
    this.text,
    required this.progress,
    required this.target,
    required this.reward,
    required this.done,
  });
  final String title;
  final String? text;
  final int progress, target, reward;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final shown = progress > target ? target : progress;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _body),
                if (text != null)
                  Text(
                    text!,
                    style: _body.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: FsColors.textMuted,
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: _Bar(done ? 1 : shown / target)),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 86,
                      child: Text(
                        done ? 'Erledigt' : '$shown / $target',
                        style: fsLabel.copyWith(
                          letterSpacing: 0.3,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: Align(
              alignment: Alignment.centerRight,
              child: done
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: FsColors.action,
                      size: 24,
                    )
                  : _Reward(reward),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------- Shop

const _categoryNames = {
  CosmeticCategory.blocks: 'BLOCKFARBEN',
  CosmeticCategory.background: 'HINTERGRÜNDE',
  CosmeticCategory.platform: 'PLATTFORMEN',
  CosmeticCategory.effect: 'EFFEKTE',
};

/// Shop für kosmetische Freischaltungen. Alles wird mit erspielten Münzen
/// bezahlt und ändert nur das Aussehen.
Future<void> showShopSheet(
  BuildContext context,
  ProfileController ctl, {
  required VoidCallback onTap,
}) {
  return _sheet(context, ctl, (context) {
    final p = ctl.profile;
    return [
      Row(
        children: [
          const Expanded(child: Text('SHOP', style: fsLabel)),
          CoinBadge(p.coins),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        'Alles hier ändert nur das Aussehen, nie das Spiel.',
        style: _body.copyWith(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: FsColors.textMuted,
        ),
      ),
      for (final c in CosmeticCategory.values) ...[
        const SizedBox(height: 18),
        Text(_categoryNames[c]!, style: fsLabel),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, box) {
            final w = (box.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final item in Cosmetics.of(c))
                  SizedBox(
                    width: w,
                    child: _ShopItem(
                      item: item,
                      profile: p,
                      onTap: () => _onItem(context, ctl, item, onTap),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ];
  });
}

Future<void> _onItem(
  BuildContext context,
  ProfileController ctl,
  Cosmetic item,
  VoidCallback tap,
) async {
  final p = ctl.profile;
  if (p.owns(item.id)) {
    tap();
    ctl.equip(item.id);
    return;
  }
  if (p.coins < item.price) return;
  tap();
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: FsColors.cream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        '${item.name} freischalten?',
        style: _body.copyWith(fontSize: 19),
      ),
      content: Text(
        'Das kostet ${item.price} Münzen. Danach hast du noch '
        '${p.coins - item.price}.',
        style: _body.copyWith(fontWeight: FontWeight.w500),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Abbrechen',
            style: _body.copyWith(color: FsColors.textMuted),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            'Freischalten',
            style: _body.copyWith(
              color: const Color(0xFF1F8A7B),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
  if (ok == true) ctl.buy(item.id);
}

class _ShopItem extends StatelessWidget {
  const _ShopItem({
    required this.item,
    required this.profile,
    required this.onTap,
  });
  final Cosmetic item;
  final Profile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final owned = profile.owns(item.id);
    final equipped = profile.equippedIn(item.category).id == item.id;
    final missing = item.price - profile.coins;
    final Widget status = equipped
        ? Text(
            'Ausgewählt',
            style: _body.copyWith(fontSize: 13, color: const Color(0xFF1F8A7B)),
          )
        : owned
        ? Text('Auswählen', style: _body.copyWith(fontSize: 13))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CoinIcon(size: 13),
              const SizedBox(width: 5),
              Text(
                missing > 0
                    ? '${item.price} · fehlen $missing'
                    : '${item.price}',
                style: _body.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: missing > 0 ? FsColors.textMuted : FsColors.navy,
                ),
              ),
            ],
          );
    return Semantics(
      button: true,
      label: item.name,
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: equipped ? FsColors.action : const Color(0x14202B38),
              width: equipped ? 2.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: _Preview(item),
                ),
              ),
              const SizedBox(height: 8),
              Text(item.name, style: _body),
              const SizedBox(height: 2),
              status,
            ],
          ),
        ),
      ),
    );
  }
}

/// Kleine Vorschau einer Freischaltung.
class _Preview extends StatelessWidget {
  const _Preview(this.item);
  final Cosmetic item;

  @override
  Widget build(BuildContext context) {
    switch (item.category) {
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
          child: Align(
            alignment: const Alignment(0.6, 0.2),
            child: Transform.rotate(
              angle: 0.785,
              child: Container(
                width: 26,
                height: 26,
                color: t.shape.withValues(alpha: 0.45),
              ),
            ),
          ),
        );
      case CosmeticCategory.platform:
        return ColoredBox(
          color: const Color(0x0F202B38),
          child: Center(
            child: Container(
              width: 84,
              height: 26,
              decoration: BoxDecoration(
                color: Looks.platformSwatches[item.id],
                borderRadius: BorderRadius.circular(5),
              ),
              alignment: Alignment.topCenter,
              child: Container(
                height: 9,
                decoration: const BoxDecoration(
                  color: Color(0xFFEDE6D8),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
                ),
              ),
            ),
          ),
        );
      case CosmeticCategory.effect:
        final confetti = item.id == 'fx_confetti';
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
                    shape: BoxShape.circle,
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

// ------------------------------------------------------------------ Ergebnis

/// Belohnungen einer Runde im Ergebnis: Münzen, Erfülltes und der Fortschritt
/// zur nächsten Freischaltung.
class RewardsSummary extends StatelessWidget {
  const RewardsSummary({
    super.key,
    required this.rewards,
    required this.profile,
  });
  final RoundRewards rewards;
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final lines = <(String, int)>[
      for (final q in rewards.quests) (q.text, q.reward),
      for (final a in rewards.achievements) ('Erfolg: ${a.title}', a.reward),
    ];
    final next = profile.nextUnlock;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0x0F202B38),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CoinIcon(size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '+${rewards.total} Münzen',
                  style: _body.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                'Gesamt ${profile.coins}',
                style: fsLabel.copyWith(fontSize: 12, letterSpacing: 0.4),
              ),
            ],
          ),
          for (final (text, reward) in lines.take(3))
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: FsColors.action,
                    size: 17,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _body.copyWith(fontSize: 13.5),
                    ),
                  ),
                  _Reward(reward, muted: true),
                ],
              ),
            ),
          if (lines.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 24),
              child: Text(
                'und ${lines.length - 3} weitere',
                style: fsLabel.copyWith(fontSize: 12, letterSpacing: 0.3),
              ),
            ),
          if (next != null) ...[
            const SizedBox(height: 9),
            _Bar(profile.coins / next.price, color: FsColors.reward),
            const SizedBox(height: 5),
            Text(
              profile.coins >= next.price
                  ? '${next.name} kannst du jetzt im Shop freischalten'
                  : 'Nächste Freischaltung: ${next.name} '
                        '· ${profile.coins} / ${next.price}',
              style: fsLabel.copyWith(fontSize: 12, letterSpacing: 0.3),
            ),
          ],
        ],
      ),
    );
  }
}
