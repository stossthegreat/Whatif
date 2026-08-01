import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// The "we are LIVE" chip. A hot dot that breathes, plus a label. Used on the
/// lobby and any room that has real activity happening *right now*.
class LivePill extends StatefulWidget {
  const LivePill({super.key, this.label = 'LIVE', this.color = WhatIfColors.live});
  final String label;
  final Color color;

  @override
  State<LivePill> createState() => _LivePillState();
}

class _LivePillState extends State<LivePill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: widget.color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: widget.color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              return Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withOpacity(0.4 + 0.6 * _c.value),
                      blurRadius: 6 + 6 * _c.value,
                      spreadRadius: _c.value,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 7),
          Text(
            widget.label,
            style: WhatIfType.overline.copyWith(
              color: widget.color,
              fontSize: 11,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// A generic frosted tag chip (e.g. "8 playing", "🎭 Impostor").
class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    this.icon,
    this.color,
  });

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? WhatIfColors.textMed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: WhatIfColors.glass,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: WhatIfColors.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: c),
            const SizedBox(width: 5),
          ],
          Text(label,
              style: WhatIfType.caption
                  .copyWith(color: c, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
