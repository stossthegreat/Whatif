import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../data/interest_catalog.dart';
import '../theme/tokens.dart';
import 'onboarding_shell.dart';

/// Primary language — the single biggest lever on whether a room works at all,
/// so it's asked as a promise ("we'll put you with people you can actually
/// talk to") rather than as data collection.
///
/// Pre-selected from the device locale, so most people just tap Continue.
class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key, required this.onDone, required this.onBack});
  final ValueChanged<String> onDone;
  final VoidCallback onBack;

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  late String _value = _fromLocale();

  static String _fromLocale() {
    final code = ui.PlatformDispatcher.instance.locale.languageCode.toLowerCase();
    for (final l in kLanguages) {
      if (l.code == code) return l.label;
    }
    return 'English';
  }

  @override
  Widget build(BuildContext context) {
    return OnboardStep(
      step: 4,
      total: 7,
      title: 'What do you speak?',
      accent: 'speak',
      sub: 'We’ll put you with people you can actually talk to.',
      onBack: widget.onBack,
      ctaLabel: 'Continue',
      onCta: () => widget.onDone(_value),
      child: Column(
        children: [
          for (final l in kLanguages)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _Row(
                label: l.native,
                english: l.native == l.label ? null : l.label,
                selected: _value == l.label,
                onTap: () => setState(() => _value = l.label),
              ),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, this.english, required this.selected, required this.onTap});
  final String label;
  final String? english;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            AnimatedContainer(
              duration: M.quick,
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? C.sig : Colors.transparent,
                border: Border.all(color: selected ? C.sig : C.hair2, width: 2),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 14),
            Text(label,
                style: T.body.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
            if (english != null) ...[
              const SizedBox(width: 8),
              Text(english!, style: T.tiny.copyWith(fontSize: 12.5)),
            ],
          ],
        ),
      ),
    );
  }
}
