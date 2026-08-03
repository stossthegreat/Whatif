import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../state/session.dart';
import '../theme/tokens.dart';
import '../widgets/glass.dart';
import 'onboarding_shell.dart';

/// Your handle. No real names — that's a safety feature, not a limitation, so
/// the copy says so out loud.
class HandleScreen extends StatefulWidget {
  const HandleScreen({super.key, required this.onDone, required this.onBack});
  final ValueChanged<String> onDone;
  final VoidCallback onBack;

  @override
  State<HandleScreen> createState() => _HandleScreenState();
}

class _HandleScreenState extends State<HandleScreen> {
  late final _ctl = TextEditingController(text: AppSession.instance.myHandle);

  bool get _ok =>
      RegExp(r'^[a-z0-9_]{3,14}$').hasMatch(_ctl.text.trim().toLowerCase());

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OnboardStep(
      step: 2,
      total: 7,
      title: 'What do we call you?',
      accent: 'call you',
      sub: 'Pick a handle — not your real name. This is who the room meets.',
      onBack: widget.onBack,
      ctaLabel: _ok ? 'Continue' : '3–14 letters, numbers or _',
      onCta: _ok ? () => widget.onDone(_ctl.text.trim().toLowerCase()) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: C.glass,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _ok ? C.hair2 : C.hair),
            ),
            child: Row(
              children: [
                Text('@', style: T.huge(24).copyWith(color: C.tx3)),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: _ctl,
                    autocorrect: false,
                    enableSuggestions: false,
                    maxLength: 14,
                    textInputAction: TextInputAction.done,
                    style: T.huge(24),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      isDense: true,
                      counterText: '',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Press(
            haptic: false,
            onTap: () {
              Buzz.tick();
              setState(() => _ctl.text = AppSession.instance.suggestHandle());
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.casino_rounded, size: 16, color: C.sig),
                const SizedBox(width: 8),
                Text('surprise me',
                    style: T.body.copyWith(
                        color: C.sig, fontWeight: FontWeight.w800, fontSize: 14.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
