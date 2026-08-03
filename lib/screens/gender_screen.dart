import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 'onboarding_shell.dart';

/// "I am" — locked once set.
///
/// We deliberately do NOT ask who you want to meet here. Gender is collected
/// because other people's filters read it; choosing your own filter is a
/// premium feature, not a free onboarding question.
class GenderScreen extends StatefulWidget {
  const GenderScreen({super.key, required this.onDone, required this.onBack, this.initial});
  final ValueChanged<String> onDone;
  final VoidCallback onBack;
  final String? initial;

  @override
  State<GenderScreen> createState() => _GenderScreenState();
}

class _GenderScreenState extends State<GenderScreen> {
  late String? _value = widget.initial;

  static const _options = ['Woman', 'Man', 'Non-binary'];

  @override
  Widget build(BuildContext context) {
    return OnboardStep(
      step: 3,
      total: 7,
      title: 'I am…',
      accent: 'am',
      sub: 'This is how other people’s matching preferences see you.',
      onBack: widget.onBack,
      ctaLabel: _value == null ? 'Pick one to continue' : 'Continue',
      onCta: _value == null ? null : () => widget.onDone(_value!),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final o in _options) ...[
            _Option(
              label: o,
              selected: _value == o,
              onTap: () => setState(() => _value = o),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.lock_outline_rounded, size: 14, color: C.tx3),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Choose carefully — this can’t be changed later.',
                    style: T.tiny.copyWith(fontSize: 12.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: M.quick,
        curve: M.ease,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: selected ? C.sig.withOpacity(0.16) : C.glass,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? C.sig : C.hair2, width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: T.h3.copyWith(
                      fontSize: 18, color: selected ? Colors.white : C.tx)),
            ),
            AnimatedOpacity(
              duration: M.quick,
              opacity: selected ? 1 : 0,
              child: const Icon(Icons.check_circle_rounded, size: 22, color: C.sig),
            ),
          ],
        ),
      ),
    );
  }
}
