import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../state/session.dart';
import '../theme/tokens.dart';
import '../widgets/aurora.dart';
import '../widgets/glass.dart';
import 'legal_screen.dart';

/// Sign-in. The social buttons are placeholders for now (no real auth wired yet)
/// and there's a clear **Continue for now** button to skip straight past it.
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key, required this.onContinue});
  final VoidCallback onContinue;

  void _proceed({bool signedIn = false}) {
    AppSession.instance.signedIn = signedIn;
    Buzz.commit();
    onContinue();
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Scaffold(
      backgroundColor: C.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Aurora(),
          SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: r.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 18),
              const Wordmark(size: 21),
              const Spacer(),
              RichText(
                text: TextSpan(
                  style: T.huge(42 * r.scale),
                  children: const [
                    TextSpan(text: 'Save your\n'),
                    TextSpan(text: 'vibe', style: TextStyle(color: C.sig)),
                    TextSpan(text: '.'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text('Sign in so you can reconnect with people you click with. '
                  'Or skip it — you can meet people right now.',
                  style: T.body.copyWith(fontSize: 16)),
              const SizedBox(height: 30),
              _AuthBtn(label: 'Continue with Apple', icon: Icons.apple, filled: true, onTap: () => _proceed(signedIn: true)),
              const SizedBox(height: 11),
              _AuthBtn(label: 'Continue with Google', icon: Icons.g_mobiledata_rounded, onTap: () => _proceed(signedIn: true)),
              const SizedBox(height: 11),
              _AuthBtn(label: 'Use phone number', icon: Icons.phone_iphone_rounded, onTap: () => _proceed(signedIn: true)),
              const Spacer(),
              // the skip — continue past sign-in for now
              Press(
                haptic: false,
                onTap: () => _proceed(signedIn: false),
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: C.hair2),
                  ),
                  child: Text('Continue for now  →',
                      style: T.body.copyWith(color: C.tx, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 16),
              _LegalLine(),
              const SizedBox(height: 14),
            ],
          ),
        ),
          ),
        ],
      ),
    );
  }
}

class _AuthBtn extends StatelessWidget {
  const _AuthBtn({required this.label, required this.icon, this.filled = false, required this.onTap});
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Press(
      haptic: false,
      onTap: onTap,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? Colors.white : C.glass,
          borderRadius: BorderRadius.circular(18),
          border: filled ? null : Border.all(color: C.hair2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: filled ? Colors.black : C.tx),
            const SizedBox(width: 10),
            Text(label, style: T.body.copyWith(
              color: filled ? Colors.black : C.tx, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _LegalLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('By continuing you agree to our ', style: T.tiny),
        GestureDetector(
          onTap: () => LegalScreen.push(context, 'Terms of Service', LegalCopy.terms),
          child: Text('Terms', style: T.tiny.copyWith(color: C.sig, fontWeight: FontWeight.w700)),
        ),
        Text('  &  ', style: T.tiny),
        GestureDetector(
          onTap: () => LegalScreen.push(context, 'Privacy Policy', LegalCopy.privacy),
          child: Text('Privacy', style: T.tiny.copyWith(color: C.sig, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
