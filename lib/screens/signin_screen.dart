import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../core/analytics.dart';
import '../core/haptics.dart';
import '../net/network_client.dart';
import '../state/session.dart';
import '../theme/tokens.dart';
import '../widgets/aurora.dart';
import '../widgets/glass.dart';
import 'legal_screen.dart';

/// Sign-in. One REAL button — Sign in with Apple (identity that survives
/// reinstalls) — and an honest guest path. No fake social buttons: App Review
/// taps everything, and dead buttons are an instant rejection.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.onContinue});
  final VoidCallback onContinue;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _busy = false;
  String? _error;

  // the agreement gate — all three required before ANY way in
  bool _age = false;
  bool _terms = false;
  bool _rules = false;
  bool get _ready => _age && _terms && _rules;

  void _proceed({bool signedIn = false}) {
    AppSession.instance.signedIn = signedIn;
    Buzz.commit();
    widget.onContinue();
  }

  void _needBoxes() {
    Buzz.impact();
    setState(() => _error = 'tick all three boxes first');
  }

  Future<void> _apple() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    Buzz.tick();
    try {
      // scopes deliberately EMPTY: we want only the anonymous user identifier,
      // never name or email — exactly what the privacy policy promises.
      final cred = await SignInWithApple.getAppleIDCredential(
        scopes: const [],
      );
      Track.event('apple_signin');
      final auid = cred.userIdentifier;
      if (auid != null && auid.isNotEmpty) {
        AppSession.instance.setAppleIdentity(auid);
        // the backend keys everything by uid — re-introduce ourselves so
        // sparks and mutuals attach to the Apple identity from now on
        NetworkClient.instance.hello();
      }
      if (!mounted) return;
      _proceed(signedIn: true);
    } on SignInWithAppleAuthorizationException catch (e) {
      // user cancelled — not an error, just stay
      if (mounted && e.code != AuthorizationErrorCode.canceled) {
        setState(() => _error = 'Apple sign-in didn’t work — try again or continue as guest');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Apple sign-in didn’t work — try again or continue as guest');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
                  const Wordmark(size: 30),
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
                  Text(
                      'Sign in with Apple and the people you click with stay '
                      'yours — across reinstalls, forever. Or skip it and meet '
                      'people right now.',
                      style: T.body.copyWith(fontSize: 16)),
                  const SizedBox(height: 24),
                  // ---- the agreement gate ----
                  _CheckRow(
                    checked: _age,
                    onTap: () => setState(() { _age = !_age; _error = null; }),
                    child: Text('I’m 18 or older',
                        style: T.body.copyWith(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 10),
                  _CheckRow(
                    checked: _terms,
                    onTap: () => setState(() { _terms = !_terms; _error = null; }),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('I agree to the ',
                            style: T.body.copyWith(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w600)),
                        GestureDetector(
                          onTap: () => LegalScreen.push(context, 'Terms of Service', LegalCopy.terms),
                          child: Text('Terms',
                              style: T.body.copyWith(color: C.sig, fontSize: 14.5, fontWeight: FontWeight.w700)),
                        ),
                        Text(' & ',
                            style: T.body.copyWith(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w600)),
                        GestureDetector(
                          onTap: () => LegalScreen.push(context, 'Privacy Policy', LegalCopy.privacy),
                          child: Text('Privacy Policy',
                              style: T.body.copyWith(color: C.sig, fontSize: 14.5, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _CheckRow(
                    checked: _rules,
                    onTap: () => setState(() { _rules = !_rules; _error = null; }),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('I’ll follow the ',
                            style: T.body.copyWith(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w600)),
                        GestureDetector(
                          onTap: () => LegalScreen.push(context, 'House Rules', LegalCopy.rules),
                          child: Text('House Rules',
                              style: T.body.copyWith(color: C.sig, fontSize: 14.5, fontWeight: FontWeight.w700)),
                        ),
                        Text(' — no recording, ever',
                            style: T.body.copyWith(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Opacity(
                    opacity: _ready ? 1 : 0.4,
                    child: Press(
                      haptic: false,
                      onTap: _busy ? null : (_ready ? _apple : _needBoxes),
                      child: Container(
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.black))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.apple, size: 24, color: Colors.black),
                                  const SizedBox(width: 10),
                                  Text('Sign in with Apple',
                                      style: T.body.copyWith(
                                          color: Colors.black, fontWeight: FontWeight.w700)),
                                ],
                              ),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Center(child: Text(_error!, style: T.tiny.copyWith(color: C.live))),
                  ],
                  const Spacer(),
                  Opacity(
                    opacity: _ready ? 1 : 0.4,
                    child: Press(
                      haptic: false,
                      onTap: () => _ready ? _proceed(signedIn: false) : _needBoxes(),
                      child: Container(
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: C.hair2),
                        ),
                        child: Text('Continue as guest  →',
                            style: T.body.copyWith(color: C.tx, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
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

/// One agreement row: a tappable check square + label. The links inside the
/// label stay tappable independently (reading never toggles the box).
class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.checked, required this.onTap, required this.child});
  final bool checked;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () { Buzz.tick(); onTap(); },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 24, height: 24,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: checked ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: checked ? Colors.white : C.hair2, width: 1.4),
            ),
            child: checked
                ? const Icon(Icons.check_rounded, size: 17, color: Colors.black)
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () { Buzz.tick(); onTap(); },
            child: Padding(padding: const EdgeInsets.only(top: 2), child: child),
          ),
        ),
      ],
    );
  }
}
