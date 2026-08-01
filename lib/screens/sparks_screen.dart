import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../state/session.dart';
import '../theme/tokens.dart';
import '../widgets/glass.dart';
import '../widgets/identity_orb.dart';

/// Sparks — the people you vibed with. Never called "matches"; it's just your
/// people. When it's mutual, that's a ✨. This is the quiet bridge to the vision.
class SparksScreen extends StatelessWidget {
  const SparksScreen({super.key, this.embedded = false});

  /// Hides the back button when shown as a bottom-nav tab.
  final bool embedded;

  static void push(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SparksScreen()));
  }

  void _toast(BuildContext c, String m) {
    ScaffoldMessenger.of(c)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: C.char3,
        content: Text(m, style: T.sub.copyWith(color: Colors.white)),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.black,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: AppSession.instance,
          builder: (context, _) {
            final s = AppSession.instance;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
                  child: Row(
                    children: [
                      if (!embedded) ...[
                        Press(
                          onTap: () => Navigator.of(context).maybePop(),
                          child: Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: C.glass, border: Border.all(color: C.hair)),
                            child: const Icon(Icons.arrow_back_rounded, size: 20, color: C.tx2),
                          ),
                        ),
                        const SizedBox(width: 14),
                      ],
                      Text('Sparks', style: T.big.copyWith(fontSize: 26)),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(embedded ? 20 : 72, 0, 20, 10),
                  child: Text('${s.sparks.length} people · ${s.mutualCount} ✨ mutual', style: T.tiny),
                ),
                Expanded(
                  child: s.sparks.isEmpty
                      ? _empty()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                          itemCount: s.sparks.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) => _SparkRow(spark: s.sparks[i], onWave: () {
                            Buzz.commit();
                            _toast(context, s.sparks[i].liveNow
                                ? 'joining @${s.sparks[i].name}…'
                                : 'we’ll ping you when @${s.sparks[i].name} is live');
                          }),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✨', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 16),
            Text('No sparks yet', style: T.h3, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Hit ♡ on someone you vibe with in a room. They’ll show up here — and when it’s mutual, it’s a spark.',
                style: T.body, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _SparkRow extends StatelessWidget {
  const _SparkRow({required this.spark, required this.onWave});
  final Spark spark;
  final VoidCallback onWave;

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 22,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          IdentityOrb(hue: spark.hue, size: 52, live: spark.liveNow, ring: spark.mutual ? C.sig : null),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('@${spark.name}', style: T.body.copyWith(color: C.tx, fontWeight: FontWeight.w700)),
                    if (spark.mutual) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: C.sig.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: C.sig.withOpacity(0.5)),
                        ),
                        child: Text('✨ mutual', style: T.tiny.copyWith(color: C.sig, fontWeight: FontWeight.w800, fontSize: 10)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(spark.liveNow ? 'live now · ${spark.vibe}' : spark.vibe,
                    style: T.tiny.copyWith(color: spark.liveNow ? const Color(0xFF3BE07A) : C.tx3)),
              ],
            ),
          ),
          Press(
            onTap: onWave,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: spark.liveNow ? Colors.white : C.glass,
                borderRadius: BorderRadius.circular(100),
                border: spark.liveNow ? null : Border.all(color: C.hair2),
              ),
              child: Text(spark.liveNow ? 'join' : 'wave',
                  style: T.tiny.copyWith(color: spark.liveNow ? Colors.black : C.tx, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}
