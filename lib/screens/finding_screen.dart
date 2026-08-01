import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../theme/tokens.dart';
import '../widgets/countdown_ring.dart';
import '../widgets/self_view.dart';

/// Finding — the held breath. Not a spinner: a reveal countdown with a finish
/// line. The ring fills, the number ticks 2→1, haptics ramp — then it hands off
/// to the drop. This ~1.5s is the most important surface in the product.
class FindingScreen extends StatefulWidget {
  const FindingScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<FindingScreen> createState() => _FindingScreenState();
}

class _FindingScreenState extends State<FindingScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  bool _flipped = false;

  @override
  void initState() {
    super.initState();
    Buzz.ramp();
    _c
      ..addListener(() {
        if (!_flipped && _c.value > 0.5) {
          _flipped = true;
          Buzz.tick();
          setState(() {});
        }
      })
      ..forward().whenComplete(() {
        if (mounted) widget.onDone();
      });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) => RingPaint(
                progress: _c.value,
                size: 224,
                child: SizedBox(
                  width: 122,
                  height: 122,
                  child: ClipOval(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const SelfView(),
                        DecoratedBox(
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.15)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Text('CONNECTING', style: T.eyebrow),
            const SizedBox(height: 10),
            Text(_flipped ? '1' : '2', style: T.mono.copyWith(fontSize: 22, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }
}
