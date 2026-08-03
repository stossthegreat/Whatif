import 'package:flutter/material.dart';
import '../data/interest_catalog.dart';
import '../theme/tokens.dart';
import 'onboarding_shell.dart';

/// Interests — the strongest signal in the matching scorer, so this screen
/// earns its length. Grouped under emoji headers with horizontally scrolling
/// rows so 80+ options never feel like a wall.
///
/// The button carries the requirement ("Pick 3 to continue") rather than just
/// greying out, so nobody has to guess why it's dead.
class InterestsScreen extends StatefulWidget {
  const InterestsScreen({
    super.key,
    required this.onDone,
    required this.onBack,
    this.initial = const <String>[],
  });
  final ValueChanged<List<String>> onDone;
  final VoidCallback onBack;
  final List<String> initial;

  @override
  State<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends State<InterestsScreen> {
  late final Set<String> _picked = {...widget.initial};
  static const _min = 3;

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final n = _picked.length;
    final ok = n >= _min;
    return OnboardStep(
      step: 5,
      total: 7,
      title: 'What are you into?',
      accent: 'into',
      sub: 'Pick at least $_min. We put you with people who share them — this '
          'is what makes a room click instead of dying in ten seconds.',
      onBack: widget.onBack,
      ctaLabel: ok
          ? 'Continue  ·  $n picked'
          : 'Pick ${_min - n} more to continue',
      onCta: ok ? () => widget.onDone(_picked.toList()) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final g in kInterestGroups) ...[
            Row(
              children: [
                Text(g.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 9),
                Text(g.name.toUpperCase(),
                    style: T.eyebrow.copyWith(color: C.tx2, fontSize: 11.5)),
              ],
            ),
            const SizedBox(height: 11),
            // full-bleed row: chips run past the gutter so it reads as
            // scrollable without needing an affordance
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.only(right: r.gutter),
                clipBehavior: Clip.none,
                itemCount: g.items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final item = g.items[i];
                  return OnboardChip(
                    label: item,
                    selected: _picked.contains(item),
                    onTap: () => setState(() {
                      if (!_picked.remove(item)) _picked.add(item);
                    }),
                  );
                },
              ),
            ),
            const SizedBox(height: 22),
          ],
        ],
      ),
    );
  }
}
