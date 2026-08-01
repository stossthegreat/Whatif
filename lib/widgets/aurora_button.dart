import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'pressable.dart';

/// The primary call-to-action. A pill filled with the aurora sweep, sitting in
/// its own colored glow so it reads as the one hot thing on the screen. It
/// breathes faintly at rest (a slow shimmer sweeps across it) so even an idle
/// CTA feels alive and invites the tap.
class AuroraButton extends StatefulWidget {
  const AuroraButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.gradient = WhatIfColors.aurora,
    this.expand = true,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final List<Color> gradient;
  final bool expand;
  final bool enabled;

  @override
  State<AuroraButton> createState() => _AuroraButtonState();
}

class _AuroraButtonState extends State<AuroraButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glowColor = widget.gradient.first;
    final content = AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) {
        return Container(
          height: 62,
          width: widget.expand ? double.infinity : null,
          padding: EdgeInsets.symmetric(horizontal: widget.expand ? 24 : 34),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: widget.enabled
                  ? widget.gradient
                  : [WhatIfColors.inkRaised, WhatIfColors.inkRaised],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: widget.enabled
                ? [
                    BoxShadow(
                      color: glowColor.withOpacity(0.5),
                      blurRadius: 32,
                      spreadRadius: -4,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: ShaderMask(
            // A moving band of extra light travels across the label + fill.
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) {
              final x = _shimmer.value;
              return LinearGradient(
                begin: Alignment(-1 + 3 * x, 0),
                end: Alignment(-0.4 + 3 * x, 0),
                colors: [
                  Colors.white.withOpacity(0),
                  Colors.white.withOpacity(widget.enabled ? 0.28 : 0),
                  Colors.white.withOpacity(0),
                ],
              ).createShader(bounds);
            },
            child: Row(
              mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon,
                      size: 20,
                      color: widget.enabled
                          ? Colors.white
                          : WhatIfColors.textLow),
                  const SizedBox(width: 10),
                ],
                Text(
                  widget.label,
                  style: WhatIfType.bodyStrong.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color:
                        widget.enabled ? Colors.white : WhatIfColors.textLow,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    return Pressable(
      haptic: false,
      onTap: widget.enabled
          ? () {
              Buzz.commit();
              widget.onTap?.call();
            }
          : null,
      child: content,
    );
  }
}

/// A quieter secondary action — glass pill, hairline border, no glow.
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: WhatIfColors.glass,
          border: Border.all(color: WhatIfColors.hairlineStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: WhatIfColors.textHigh),
              const SizedBox(width: 10),
            ],
            Text(label,
                style: WhatIfType.bodyStrong.copyWith(color: WhatIfColors.textHigh)),
          ],
        ),
      ),
    );
  }
}
