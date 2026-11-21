import 'package:flutter/material.dart';

import '../../game/meta/rewards.dart';
import '../../services/storage/profile_store.dart';
import '../../shared/theme/fs_colors.dart';
import '../../shared/widgets/fs_widgets.dart';

const _body = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w600,
  color: FsColors.navy,
);

/// Münze: in Blender gerendert (tools/blender/render_coin.py). Für kleine
/// Grössen gibt es ein eigenes Bild mit vereinfachter Prägung.
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 18});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      size <= 24 ? 'assets/ui/coin_small.png' : 'assets/ui/coin.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
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
        padding: const EdgeInsets.fromLTRB(9, 6, 14, 6),
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
            const CoinIcon(size: 22),
            const SizedBox(width: 6),
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
        const SizedBox(width: 4),
        const CoinIcon(size: 17),
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            children: children(context),
          ),
        ),
      ),
    ),
  );
}

// ------------------------------------------------------------------ Aufgaben

String _untilMidnight(DateTime now) {
  final left = DateTime(now.year, now.month, now.day + 1).difference(now);
  return left.inHours >= 1
      ? 'neu in ${left.inHours} Std.'
      : 'neu in ${left.inMinutes + 1} Min.';
}

String _untilMonday(DateTime now) {
  final days = 8 - now.weekday;
  return days == 1 ? 'neu morgen' : 'neu in $days Tagen';
}

/// Tagesaufgaben, Wochenaufgaben und Erfolge als Blatt von unten.
Future<void> showQuestsSheet(BuildContext context, ProfileController ctl) {
  ctl.refresh();
  var showAll = false;
  return _sheet(context, ctl, (context) {
    final p = ctl.profile;
    final now = DateTime.now();
    // Je Reihe nur die nächste Stufe, die am weitesten fortgeschrittene zuerst
    final open = Achievements.nextOpen(p.achievements)
      ..sort(
        (a, b) => (p.counter(b.counter) / b.target).compareTo(
          p.counter(a.counter) / a.target,
        ),
      );
    final done = [
      for (final a in Achievements.all)
        if (p.achievements.contains(a.id)) a,
    ];
    Widget achievement(Achievement a) => _ProgressRow(
      title: a.title,
      text: a.text,
      progress: p.counter(a.counter),
      target: a.target,
      reward: a.reward,
      done: p.achievements.contains(a.id),
    );
    return [
      _Section('HEUTE', _untilMidnight(now), [
        for (final q in p.daily) _QuestRow(q),
      ]),
      const SizedBox(height: 12),
      _Section('DIESE WOCHE', _untilMonday(now), [
        for (final q in p.weekly) _QuestRow(q),
      ]),
      const SizedBox(height: 12),
      StatefulBuilder(
        builder: (context, setState) => _Section(
          'ERFOLGE',
          '${done.length} von ${Achievements.all.length}',
          [
            for (final a in showAll ? [...open, ...done] : open.take(3))
              achievement(a),
            Pressable(
              onTap: () => setState(() => showAll = !showAll),
              child: Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 2),
                child: Center(
                  child: Text(
                    showAll ? 'WENIGER ZEIGEN' : 'ALLE ZEIGEN',
                    style: fsLabel.copyWith(fontSize: 12, color: FsColors.navy),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Center(
        child: Text(
          'Belohnungen kommen am Ende der Runde von selbst.',
          style: _body.copyWith(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: FsColors.textMuted,
          ),
        ),
      ),
    ];
  });
}

/// Abschnitt des Aufgabenblatts als ruhige Karte.
class _Section extends StatelessWidget {
  const _Section(this.title, this.note, this.children);
  final String title, note;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: fsLabel.copyWith(fontSize: 11.5, color: FsColors.navy),
                ),
              ),
              Text(note, style: fsLabel.copyWith(letterSpacing: 0.3)),
            ],
          ),
          ...children,
        ],
      ),
    );
  }
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
              const CoinIcon(size: 24),
              const SizedBox(width: 6),
              Expanded(
                child: TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: rewards.total),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => Text(
                    '+$v Münzen',
                    style: _body.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              Text(
                'Gesamt ${profile.coins}',
                style: fsLabel.copyWith(fontSize: 12, letterSpacing: 0.4),
              ),
            ],
          ),
          for (final (text, reward) in lines.take(2))
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
          if (lines.length > 2)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 24),
              child: Text(
                'und ${lines.length - 2} weitere',
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
