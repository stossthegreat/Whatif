import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../state/session.dart';
import '../theme/tokens.dart';
import '../widgets/glass.dart';
import 'legal_screen.dart';

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
                          s.signedIn ? 'signed in' : 'guest',
                        ].join('\n')),
                  ]),
                  const SizedBox(height: 20),
                  _section('PREFERENCES'),
                  _card([
                    _toggle('Haptics', s.hapticsOn, (v) => setState(() { s.hapticsOn = v; Buzz.enabled = v; })),
                    _divider(),
                    _toggle('Sound', s.soundOn, (v) => setState(() => s.soundOn = v)),
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
                    _link('About Rivlr', () => LegalScreen.push(context, 'About', LegalCopy.about)),
                    _divider(),
                    _info('Contact', 'appsdevelop2025@gmail.com'),
                  ]),
                  const SizedBox(height: 20),
                  _section('ACCOUNT'),
                  _card([
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
                  Center(child: Text('Rivlr · 1.0.0 (23)', style: T.tiny)),
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
              AppSession.instance.signOut(); // wipes device data + identity
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

  Widget _link(String label, VoidCallback onTap, {Color color = C.tx}) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Expanded(child: Text(label, style: T.body.copyWith(color: color, fontWeight: FontWeight.w600))),
              if (color == C.tx) const Icon(Icons.chevron_right_rounded, size: 20, color: C.tx3),
            ],
          ),
        ),
      );
}
