import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../core/nsfw_guard.dart';
import '../models/person.dart';
import '../theme/tokens.dart';
import 'glass.dart';

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

  /// The boundary the safety scanner captures from. Only the REMOTE video is
  /// watched — scanning your own camera would be checking the one person who
  /// already knows what they're doing.
  final GlobalKey _frameKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.popDelay, () {
      if (mounted) _pop.forward();
    });
    _maybeWatch();
  }

  @override
  void didUpdateWidget(PresenceTile old) {
    super.didUpdateWidget(old);
    // a new person in the tile means the previous verdict is meaningless
    if (old.person.id != widget.person.id) {
      NsfwGuard.instance.stop();
      _maybeWatch();
    } else if (old.videoChild == null && widget.videoChild != null) {
      _maybeWatch(); // their camera just came up
    }
  }

  void _maybeWatch() {
    if (widget.videoChild == null) return;
    NsfwGuard.instance.watch(_frameKey, autoReport: widget.onReport);
  }

  @override
  void dispose() {
    NsfwGuard.instance.stop();
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
              // live video (if any) else the pooled-light placeholder.
              // RepaintBoundary is what makes the frame capturable at all.
              if (widget.videoChild != null)
                RepaintBoundary(key: _frameKey, child: widget.videoChild!)
              else
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
              // THE COVER. Sits over the video and under the handle, so a
              // blurred person is still identifiable enough to report. Blur
              // plus an opaque wash: a heavy blur alone can still leave a
              // recognisable shape, and the point is that nobody has to see it.
              if (widget.videoChild != null)
                ValueListenableBuilder<bool>(
                  valueListenable: NsfwGuard.instance.blurred,
                  builder: (context, on, _) => IgnorePointer(
                    ignoring: !on,
                    child: AnimatedOpacity(
                      opacity: on ? 1 : 0,
                      duration: const Duration(milliseconds: 160),
                      child: on ? _NsfwCover(onReport: widget.onReport) : const SizedBox.shrink(),
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
                    // who you're actually talking to — the single most useful
                    // label on the screen, so it reads at a glance rather than
                    // hiding at caption size
                    Text('@${p.name}',
                        style: T.display(17).copyWith(
                          color: Colors.white,
                          shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 8)],
                        )),
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
              // REPORT — visible, top-left, on every face that can be reported.
              //
              // The long-press above still works and stays, but a gesture with
              // nothing on screen to advertise it is not a mechanism anyone can
              // find. App Store guideline 1.2 asks for "a mechanism for users
              // to flag objectionable content", and the live video tile is
              // exactly where objectionable content appears — a reviewer on a
              // call who sees no way to report concludes there isn't one.
              // Small and low-contrast so it stays out of the way of the face,
              // but never hidden.
              if (widget.onReport != null)
                Positioned(
                  left: 9,
                  top: 8,
                  child: Press(
                    haptic: false,
                    onTap: widget.onReport,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.42),
                        border: Border.all(color: const Color(0x33FFFFFF)),
                      ),
                      child: const Icon(Icons.flag_outlined,
                          size: 15, color: Colors.white),
                    ),
                  ),
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


/// What you see instead of someone who has gone too far. Deliberately calm:
/// this is a shield, not an accusation, and the classifier is occasionally
/// wrong — so there is always a way back to the video.
class _NsfwCover extends StatelessWidget {
  const _NsfwCover({this.onReport});
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          color: const Color(0xE6120C1C),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🫣', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 14),
              Text('Camera hidden',
                  textAlign: TextAlign.center, style: T.display(20)),
              const SizedBox(height: 8),
              Text(
                'We covered this because it looks like it breaks the rules.',
                textAlign: TextAlign.center,
                style: T.body.copyWith(fontSize: 13.5, height: 1.4, color: C.tx2),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (onReport != null)
                    Press(
                      onTap: () { Buzz.commit(); onReport!(); },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                        decoration: BoxDecoration(
                          color: C.live,
                          borderRadius: BorderRadius.circular(R.chip),
                        ),
                        child: Text('Report',
                            style: T.body.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14)),
                      ),
                    ),
                  const SizedBox(width: 10),
                  // the classifier gets it wrong sometimes; never trap anyone
                  // behind a machine's guess
                  Press(
                    haptic: false,
                    onTap: () { Buzz.tick(); NsfwGuard.instance.showAnyway(); },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                      decoration: BoxDecoration(
                        color: C.glass2,
                        borderRadius: BorderRadius.circular(R.chip),
                        border: Border.all(color: C.hair2),
                      ),
                      child: Text('Show anyway',
                          style: T.body.copyWith(
                              color: C.tx2, fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
