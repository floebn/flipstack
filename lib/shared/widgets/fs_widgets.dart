import 'package:flutter/material.dart';

import '../theme/fs_colors.dart';

const fsLabel = TextStyle(
  fontSize: 10.5,
  letterSpacing: 1.3,
  fontWeight: FontWeight.w700,
  color: FsColors.textMuted,
);

/// Macht ein Element antippbar und lässt es beim Drücken leicht nachgeben.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.onTap,
    required this.child,
    this.enabled = true,
  });
  final VoidCallback onTap;
  final Widget child;
  final bool enabled;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.94 : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Grosse Hauptaktion (Spielen, Ablegen, Nochmal).
class PillButton extends StatelessWidget {
  const PillButton(
    this.label, {
    super.key,
    required this.onTap,
    this.enabled = true,
    this.height = 62,
    this.color = FsColors.action,
    this.textColor = Colors.white,
  });
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final double height;
  final Color color, textColor;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? color : FsColors.disabled,
          borderRadius: BorderRadius.circular(height / 2),
          boxShadow: enabled
              ? const [
                  BoxShadow(
                    color: Color(0x33202B38),
                    blurRadius: 12,
                    offset: Offset(0, 5),
                  ),
                ]
              : const [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 17,
            letterSpacing: 2,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton(
    this.icon, {
    super.key,
    required this.onTap,
    this.size = 66,
    this.color = FsColors.navy,
    this.iconColor = FsColors.cream,
    this.semanticLabel,
  });
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Color color, iconColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Pressable(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Color(0x33202B38),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: iconColor, size: size * 0.48),
        ),
      ),
    );
  }
}

class FsChip extends StatelessWidget {
  const FsChip(
    this.text, {
    super.key,
    required this.color,
    this.textColor = Colors.white,
  });
  final String text;
  final Color color, textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

/// Pulsierender Ring, der im Tutorial auf ein Bedienelement hinweist.
class PulseRing extends StatefulWidget {
  const PulseRing({
    super.key,
    required this.active,
    required this.child,
    this.radius = 40,
  });
  final bool active;
  final Widget child;
  final double radius;

  @override
  State<PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<PulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat();
  }

  @override
  void didUpdateWidget(PulseRing old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) _c.repeat();
    if (!widget.active && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          boxShadow: [
            BoxShadow(
              color: FsColors.amber.withValues(alpha: 0.85 * (1 - _c.value)),
              spreadRadius: 3 + 12 * _c.value,
            ),
          ],
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Karte auf Creme-Grund mit weichem Schatten.
class FsCard extends StatelessWidget {
  const FsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(24, 22, 24, 20),
  });
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: FsColors.cream,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33202B38),
            blurRadius: 30,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}
