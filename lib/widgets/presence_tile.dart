import 'package:flutter/material.dart';
import '../models/person.dart';
import '../theme/tokens.dart';

/// A person's tile. In production this is their live video; here it's an elegant
/// "presence" surface — a cool light pooled on near-black, a specular edge, a
/// handle. Reflects live states (speaking / picked / win) and offers the
/// one-gesture Report (long-press) and opt-in Save (reconnect).
class PresenceTile extends StatefulWidget {
  const PresenceTile({
    super.key,
    required this.person,
    this.speaking = false,
    this.picked = false,
    this.win = false,
    this.dimmed = false,
    this.saved = false,
    this.connecting = false,
    this.radius = 20,
    this.popDelay = Duration.zero,
    this.videoChild,
    this.onTap,
    this.onSave,
    this.onReport,
  });

  final Person person;

  /// Corner radius. 0 for the full-bleed live wall.
  final double radius;

  /// When set (live mode), this fills the tile (the participant's video) instead
  /// of the placeholder light pool.
  final Widget? videoChild;
  final bool speaking;
  final bool picked;
  final bool win;
  final bool dimmed;
  final bool saved;

  /// Real person whose video hasn't arrived yet — label the tile as loading so
  /// it never reads as an empty ghost.
  final bool connecting;
  final Duration popDelay;
  final VoidCallback? onTap;
  final VoidCallback? onSave;
  final VoidCallback? onReport;

  @override
  State<PresenceTile> createState() => _PresenceTileState();
}

class _PresenceTileState extends State<PresenceTile> with SingleTickerProviderStateMixin {
  late final AnimationController _pop =
      AnimationController(vsync: this, duration: M.slow);

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.popDelay, () {
      if (mounted) _pop.forward();
    });
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.person;
    final border = widget.picked
        ? Border.all(color: C.sig, width: 2.5)
        : Border.all(color: const Color(0x0FFFFFFF), width: 1);

    final boxShadow = <BoxShadow>[
      if (widget.speaking || widget.picked)
        BoxShadow(color: C.sigGlow.withOpacity(0.5), blurRadius: 30, spreadRadius: -6),
    ];

    Widget tile = GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onReport,
      child: AnimatedContainer(
        duration: M.quick,
        curve: M.ease,
        decoration: BoxDecoration(
          color: const Color(0xFF0B0C0F),
          borderRadius: BorderRadius.circular(widget.radius),
          border: border,
          boxShadow: boxShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.radius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // live video (if any) else the pooled-light placeholder
              widget.videoChild ??
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(p.lx * 2 - 1, p.ly * 2 - 1),
                        radius: 0.9,
                        colors: [p.light, const Color(0x00000000)],
                        stops: const [0.0, 0.72],
                      ),
                    ),
                  ),
              // bottom legibility scrim so the handle always reads over video
              const Positioned(
                left: 0, right: 0, bottom: 0, height: 56,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter, end: Alignment.topCenter,
                        colors: [Color(0x99000000), Color(0x00000000)],
                      ),
                    ),
                  ),
                ),
              ),
              // specular top edge
              Positioned(
                top: 0,
                left: 12,
                right: 12,
                child: Container(
                  height: 1,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0x00FFFFFF), C.spec, Color(0x00FFFFFF)]),
                  ),
                ),
              ),
              // win pulse
              if (widget.win)
                TweenAnimationBuilder<double>(
                  key: const ValueKey('win'),
                  tween: Tween(begin: 1, end: 0),
                  duration: const Duration(milliseconds: 1100),
                  curve: M.ease,
                  builder: (context, v, __) => DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.radius),
                      border: Border.all(color: Colors.white.withOpacity(v), width: 2),
                    ),
                  ),
                ),
              // handle (+ honest connecting state while their video warms up)
              Positioned(
                left: 12,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('@${p.name}',
                        style: T.tiny.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
                    if (widget.connecting)
                      Text('connecting camera…',
                          style: T.tiny.copyWith(color: C.tx3, fontSize: 10)),
                  ],
                ),
              ),
              // save — always available, on every person (bottom-right heart)
              if (widget.onSave != null)
                Positioned(
                  right: 9,
                  bottom: 8,
                  child: _SaveHeart(saved: widget.saved, onTap: widget.onSave),
                ),
            ],
          ),
        ),
      ),
    );

    if (widget.dimmed) {
      tile = Opacity(opacity: 0.4, child: tile);
    }

    // pop-in
    return AnimatedBuilder(
      animation: _pop,
      builder: (context, child) {
        final v = Curves.easeOutBack.transform(_pop.value.clamp(0, 1));
        return Opacity(
          opacity: _pop.value.clamp(0, 1),
          child: Transform.scale(scale: 0.92 + 0.08 * v, child: child),
        );
      },
      child: tile,
    );
  }
}

/// The save control — a labeled pill so it's unmistakably a button.
/// ♡ Save (dark) → ✓ Saved (white). Tap to keep this person.
class _SaveHeart extends StatelessWidget {
  const _SaveHeart({required this.saved, this.onTap});
  final bool saved;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: M.quick,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: saved ? Colors.white : const Color(0x73000000),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: saved ? Colors.white : const Color(0x59FFFFFF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              saved ? Icons.check_rounded : Icons.favorite_border_rounded,
              size: 14,
              color: saved ? Colors.black : Colors.white,
            ),
            const SizedBox(width: 5),
            Text(
              saved ? 'Saved' : 'Save',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: saved ? Colors.black : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
