import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import '../core/apple_auth.dart';
import '../core/haptics.dart';
import '../net/network_client.dart';
import '../state/session.dart';
import '../theme/tokens.dart';
import '../widgets/glass.dart';
import 'legal_screen.dart';
import 'plus_screen.dart';

/// Settings — profile summary, preferences, legal, and account.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.onSignOut});
  final VoidCallback onSignOut;

  static void push(BuildContext context, VoidCallback onSignOut) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SettingsScreen(onSignOut: onSignOut),
    ));
  }

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final s = AppSession.instance;

  @override
  Widget build(BuildContext context) {
    final profileLine = [
      if (s.age != null) '${s.age}',
      if (s.gender != null) s.gender!,
    ].join(' · ');

    return Scaffold(
      backgroundColor: C.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 6, 22, 10),
              child: Row(
                children: [
                  Press(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: C.glass, border: Border.all(color: C.hair)),
                      child: const Icon(Icons.arrow_back_rounded, size: 20, color: C.tx2),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text('Settings', style: T.big.copyWith(fontSize: 26)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
                children: [
                  _section('YOU'),
                  _card([
                    _info('@${s.myHandle}',
                        [
                          if (profileLine.isNotEmpty) profileLine,
                          if (s.myVibes.isNotEmpty) s.myVibes.join(' · '),
                          // no guest path exists any more; anyone here signed
                          // in with Apple or Google to get this far
                          s.signedIn ? 'signed in' : 'not signed in',
                        ].join('\n')),
                  ]),
                  const SizedBox(height: 20),
                  _section('RIVLER PRO'),
                  _card([
                    _link(
                      s.plus ? 'Who you meet · ${_meetLabel(s.meetPref)}' : 'Choose who you meet',
                      () {
                        Buzz.tick();
                        if (s.plus) {
                          _meetSheet();
                        } else {
                          PlusScreen.push(context, reason: 'Meet only women, or only men.');
                        }
                      },
                      trailing: s.plus ? null : 'Rivler+',
                    ),
                    _divider(),
                    if (s.plus)
                      _info('Subscription',
                          'active — manage or cancel in your Apple ID settings')
                    else
                      _link('See what Rivler+ unlocks',
                          () { Buzz.tick(); PlusScreen.push(context); }),
                  ]),
                  const SizedBox(height: 20),
                  _section('PREFERENCES'),
                  _card([
                    _toggle('Haptics', s.hapticsOn, (v) => setState(() { s.hapticsOn = v; Buzz.enabled = v; })),
                    _divider(),
                    _toggle('Sound', s.soundOn, (v) => setState(() => s.soundOn = v)),
                  ]),
                  const SizedBox(height: 20),
                  _section('SAFETY'),
                  _card([
                    if (s.blocked.isEmpty)
                      _info('Blocked people', 'nobody — block from any room via ⋯')
                    else
                      for (final e in s.blocked)
                        _blockedRow(
                          e.split('|').first,
                          e.split('|').length > 1 ? e.split('|')[1] : 'someone',
                        ),
                  ]),
                  const SizedBox(height: 20),
                  _section('ABOUT'),
                  _card([
                    _link('House Rules', () => LegalScreen.push(context, 'House Rules', LegalCopy.rules)),
                    _divider(),
                    _link('Privacy Policy', () => LegalScreen.push(context, 'Privacy Policy', LegalCopy.privacy)),
                    _divider(),
                    _link('Terms of Service', () => LegalScreen.push(context, 'Terms of Service', LegalCopy.terms)),
                    _divider(),
                    _link('About Rivler', () => LegalScreen.push(context, 'About', LegalCopy.about)),
                    _divider(),
                    // Guideline 1.2 requires contact information IN THE APP,
                    // giving users a way to report inappropriate activity.
                    // A non-interactive label satisfies the letter of that and
                    // not the intent — a reviewer looking for it needs to be
                    // able to do something with it, so this copies the address.
                    _link('Report a problem · m2mb@info.com', () async {
                      await Clipboard.setData(
                          const ClipboardData(text: 'm2mb@info.com'));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: C.char2,
                        content: Text(
                          'Email copied — m2mb@info.com. We answer reports '
                          'within 24 hours.',
                          style: T.body.copyWith(color: Colors.white),
                        ),
                      ));
                    }),
                  ]),
                  const SizedBox(height: 20),
                  _section('DISCOVERY'),
                  _card([
                    _toggle('Show me in Explore', s.discoverable, (v) {
                      setState(() => s.setDiscoverable(v));
                      NetworkClient.instance.setProfile({'discoverable': v});
                    }),
                  ]),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                    child: Text(
                      'On: other signed-in adults can see your card while you’re '
                      'online and ask to meet — you always choose whether to accept. '
                      'Off: you vanish from Explore and can still play and message.',
                      style: T.tiny.copyWith(fontSize: 12, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 26),
                  _section('ACCOUNT'),
                  _card([
                    if (!s.signedIn) ...[
                      _link('Sign in with Apple — keep your people forever', () async {
                        Buzz.commit();
                        final ok = await appleSignIn();
                        if (ok && mounted) setState(() {});
                      }, color: C.sig),
                      _divider(),
                    ],
                    _link('Sign out', () {
                      Buzz.commit();
                      AppSession.instance.signOut();
                      Navigator.of(context).pop();
                      widget.onSignOut();
                    }, color: C.tx),
                    _divider(),
                    _link('Delete account', () => _confirmDelete(context), color: C.live),
                  ]),
                  const SizedBox(height: 26),
                  Center(child: Text('Rivler · 1.0.0 (70)', style: T.tiny)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.char2,
        title: Text('Delete account?', style: T.h3),
        content: Text('This will permanently remove your account and data. This can’t be undone.',
            style: T.body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: T.body.copyWith(color: C.tx2))),
          TextButton(
            onPressed: () {
              // server first (deletes DB rows), then wipe the device
              NetworkClient.instance.deleteAccount();
              AppSession.instance.signOut();
              Navigator.pop(ctx);
              Navigator.pop(context);
              widget.onSignOut();
            },
            child: Text('Delete', style: T.body.copyWith(color: C.live, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _blockedRow(String uid, String name) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text('@$name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: T.body.copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
          ),
          Press(
            onTap: () {
              Buzz.tick();
              AppSession.instance.removeBlocked(uid);
              NetworkClient.instance.unblock(uid);
              setState(() {});
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: C.hair2),
              ),
              child: Text('Unblock', style: T.tiny.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  // ---- pieces ----
  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(left: 6, bottom: 10),
        child: Text(t, style: T.eyebrow),
      );

  Widget _card(List<Widget> children) => Glass(
        radius: 22,
        padding: EdgeInsets.zero,
        child: Column(children: children),
      );

  Widget _divider() => const Divider(height: 1, color: C.hair, indent: 18, endIndent: 18);

  Widget _info(String title, String sub) => Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: T.body.copyWith(color: C.tx, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(sub, style: T.tiny),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(label, style: T.body.copyWith(color: C.tx))),
            Switch(
              value: value,
              onChanged: (v) { Buzz.tick(); onChanged(v); },
              activeColor: Colors.white,
              activeTrackColor: C.sig,
              inactiveThumbColor: C.tx2,
              inactiveTrackColor: C.char3,
            ),
          ],
        ),
      );

  Widget _link(String label, VoidCallback onTap, {Color color = C.tx, String? trailing}) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Expanded(child: Text(label, style: T.body.copyWith(color: color, fontWeight: FontWeight.w600))),
              if (trailing != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: C.gradSig,
                    borderRadius: BorderRadius.circular(R.chip),
                  ),
                  child: Text(trailing,
                      style: T.tiny.copyWith(
                          color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 8),
              ],
              if (color == C.tx) const Icon(Icons.chevron_right_rounded, size: 20, color: C.tx3),
            ],
          ),
        ),
      );

  static String _meetLabel(String meet) => switch (meet) {
        'Women' => 'women only',
        'Men' => 'men only',
        _ => 'everyone',
      };

  /// The paid filter picker. Honest about what it can and can't promise:
  /// gender here is what each person selected about themselves.
  void _meetSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(12),
        child: Glass(
          radius: R.sheet,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
          child: AnimatedBuilder(
            animation: AppSession.instance,
            builder: (ctx2, _) {
              final cur = AppSession.instance.meetPref;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('WHO YOU MEET', style: T.eyebrow),
                  const SizedBox(height: 12),
                  for (final o in const [
                    ('Everyone', 'everyone', '🌍'),
                    ('Women', 'women only', '♀︎'),
                    ('Men', 'men only', '♂︎'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Press(
                        haptic: false,
                        onTap: () {
                          Buzz.commit();
                          NetworkClient.instance.meetPref(o.$1);
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            gradient: cur == o.$1 ? C.gradSig : null,
                            color: cur == o.$1 ? null : C.glass,
                            borderRadius: BorderRadius.circular(R.btn),
                            border: Border.all(
                                color: cur == o.$1 ? const Color(0x47FFFFFF) : C.hair2),
                          ),
                          child: Row(
                            children: [
                              Text(o.$3, style: const TextStyle(fontSize: 17)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(o.$2,
                                    style: T.body.copyWith(
                                        color: Colors.white, fontWeight: FontWeight.w700)),
                              ),
                              if (cur == o.$1)
                                const Icon(Icons.check_rounded, size: 19, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'Filtering means fewer people to match with, so busy hours '
                    'work best. Gender is what each person selected about '
                    'themselves — we don’t verify it.',
                    style: T.tiny.copyWith(fontSize: 11.5, height: 1.45),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
