import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../theme/tokens.dart';
import '../widgets/aurora.dart';
import '../widgets/glass.dart';

/// Every onboarding screen wears this: one question, giant type, a progress
/// hairline, and a single button at the bottom whose LABEL states what's
/// missing when it's disabled ("Pick 3 to continue") instead of just greying
/// out and leaving people guessing.
class OnboardStep extends StatelessWidget {
  const OnboardStep({
    super.key,
    required this.step,
    required this.total,
    required this.title,
    this.accent,
    this.sub,
    required this.child,
    required this.ctaLabel,
    this.onCta,
    this.onBack,
    this.footer,
    this.scrollable = true,
  });

  final int step;
  final int total;

  /// Headline. If [accent] appears inside it, that fragment is drawn purple.
  final String title;
  final String? accent;
  final String? sub;
  final Widget child;

  /// Label for the bottom button — pass the requirement here when [onCta] is
  /// null, e.g. "Pick 3 to continue".
  final String ctaLabel;
  final VoidCallback? onCta;
  final VoidCallback? onBack;
  final Widget? footer;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        _Headline(title: title, accent: accent, scale: r.scale),
        if (sub != null) ...[
          const SizedBox(height: 12),
          Text(sub!, style: T.body.copyWith(fontSize: 15.5, height: 1.45)),
        ],
        const SizedBox(height: 30),
        child,
        const SizedBox(height: 24),
      ],
    );

    return Scaffold(
      backgroundColor: C.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const Aurora(orbs: 3, opacity: 0.55),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // progress + back
                Padding(
                  padding: EdgeInsets.fromLTRB(r.gutter, 8, r.gutter, 0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 34,
                        child: onBack == null
                            ? null
                            : Press(
                                onTap: onBack,
                                child: const Icon(Icons.arrow_back_rounded,
                                    size: 22, color: C.tx2),
                              ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(100),
                          child: LinearProgressIndicator(
                            value: step / total,
                            minHeight: 3,
                            backgroundColor: C.char2,
                            valueColor: const AlwaysStoppedAnimation(C.sig),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 42,
                        child: Text('$step/$total',
                            textAlign: TextAlign.right, style: T.tiny),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: r.gutter),
                    child: scrollable
                        ? SingleChildScrollView(
                            physics: const BouncingScrollPhysics(), child: body)
                        : body,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(r.gutter, 0, r.gutter, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Cta(
                        label: ctaLabel,
                        onTap: onCta == null
                            ? null
                            : () {
                                Buzz.commit();
                                onCta!();
                              },
                      ),
                      if (footer != null) ...[
                        const SizedBox(height: 12),
                        footer!,
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.title, this.accent, required this.scale});
  final String title;
  final String? accent;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final style = T.huge(38 * scale);
    final a = accent;
    if (a == null || !title.contains(a)) {
      return Text(title, style: style);
    }
    final i = title.indexOf(a);
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: title.substring(0, i)),
        TextSpan(text: a, style: const TextStyle(color: C.sig)),
        TextSpan(text: title.substring(i + a.length)),
      ]),
      style: style,
    );
  }
}

/// The pill used by every picker in the flow — one look for single-select,
/// multi-select and language rows alike.
class OnboardChip extends StatelessWidget {
  const OnboardChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.emoji,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    return Press(
      haptic: false,
      onTap: () {
        Buzz.tick();
        onTap();
      },
      child: AnimatedContainer(
        duration: M.quick,
        curve: M.ease,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? Colors.white : C.glass,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: selected ? Colors.white : C.hair2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null) ...[
              Text(emoji!, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 7),
            ],
            Text(
              label,
              style: T.body.copyWith(
                color: selected ? Colors.black : C.tx,
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
