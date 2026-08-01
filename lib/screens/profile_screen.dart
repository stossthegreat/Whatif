import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../core/sound.dart';
import '../state/session.dart';
import '../theme/tokens.dart';
import '../widgets/aurora.dart';
import '../widgets/glass.dart';

/// Onboarding that shapes the experience — four beats, one question each,
/// huge type, zero clutter:
///   1 · your name        (identity — pick or shuffle a handle)
///   2 · your age         (18+ gate)
///   3 · you / meet       (the matchmaking signal)
///   4 · your vibe        (what kind of rooms find you)
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _page = PageController();
  int _step = 0;

  late final TextEditingController _handleCtl =
      TextEditingController(text: AppSession.instance.myHandle);
  int _age = 18;
  String? _gender;
  String _lookingFor = 'Everyone';
  final Set<String> _vibes = {};

  static const _genders = ['Woman', 'Man', 'Nonbinary', 'Other'];
  static const _prefs = ['Everyone', 'Women', 'Men'];
  static const _vibeOptions = [
    ['😂', 'Comedy'],
    ['🌶️', 'Flirty'],
    ['🧠', 'Deep talks'],
    ['🌀', 'Pure chaos'],
    ['🎤', 'Performing'],
    ['🎮', 'Games'],
  ];

  bool get _handleOk =>
      RegExp(r'^[a-z0-9_]{3,14}$').hasMatch(_handleCtl.text.trim().toLowerCase());

  bool _canAdvance() => switch (_step) {
        0 => _handleOk,
        1 => _age >= 18,
        2 => _gender != null,
        _ => _vibes.isNotEmpty,
      };

  void _next() {
    if (!_canAdvance()) return;
    Buzz.commit();
    Sfx.pop();
    FocusScope.of(context).unfocus();
    if (_step < 3) {
      _page.animateToPage(_step + 1,
          duration: M.base, curve: M.ease);
    } else {
      AppSession.instance.setHandle(_handleCtl.text);
      AppSession.instance.setProfile(
        age: _age,
        gender: _gender,
        lookingFor: _lookingFor,
        vibes: _vibes.toList(),
      );
      widget.onDone();
    }
  }

  void _back() {
    if (_step == 0) return;
    Buzz.tick();
    _page.animateToPage(_step - 1, duration: M.base, curve: M.ease);
  }

  @override
  void dispose() {
    _page.dispose();
    _handleCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Scaffold(
      backgroundColor: C.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Aurora(orbs: 3, opacity: 0.6),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: r.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 14),
                  // progress — a thin bar, no chrome
                  Row(
                    children: [
                      if (_step > 0)
                        Press(
                          onTap: _back,
                          child: const Padding(
                            padding: EdgeInsets.only(right: 14),
                            child:
                                Icon(Icons.arrow_back_rounded, size: 22, color: C.tx2),
                          ),
                        ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(100),
                          child: LinearProgressIndicator(
                            value: (_step + 1) / 4,
                            minHeight: 3,
                            backgroundColor: C.char2,
                            valueColor: const AlwaysStoppedAnimation<Color>(C.sig),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text('${_step + 1}/4', style: T.tiny),
                    ],
                  ),
                  Expanded(
                    child: PageView(
                      controller: _page,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (i) => setState(() => _step = i),
                      children: [
                        _stepHandle(r),
                        _stepAge(r),
                        _stepIdentity(r),
                        _stepVibes(r),
                      ],
                    ),
                  ),
                  Cta(
                    label: _step < 3 ? 'Continue' : 'Let’s go',
                    onTap: _canAdvance() ? _next : null,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- step 1 · handle ------------------------------------------------------
  Widget _stepHandle(Responsive r) {
    return _StepShell(
      headline: 'What do we\ncall you?',
      accent: 'call you',
      sub: 'No real names needed. This is who the room meets.',
      scale: r.scale,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _handleOk ? C.hair2 : C.live.withOpacity(0.6)),
            ),
            child: Row(
              children: [
                Text('@', style: T.h3.copyWith(color: C.tx3, fontSize: 20)),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _handleCtl,
                    autocorrect: false,
                    maxLength: 14,
                    style: T.h3.copyWith(color: Colors.white, fontSize: 20),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      counterText: '',
                      hintText: 'yourname',
                      hintStyle: T.h3.copyWith(color: C.tx3, fontSize: 20),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Press(
            onTap: () {
              Buzz.tick();
              setState(() =>
                  _handleCtl.text = AppSession.instance.suggestHandle());
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.casino_outlined, size: 16, color: C.sig),
                const SizedBox(width: 7),
                Text('surprise me',
                    style: T.sub.copyWith(color: C.sig, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          if (!_handleOk && _handleCtl.text.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('3–14 characters · letters, numbers, underscores',
                style: T.tiny.copyWith(color: C.live)),
          ],
        ],
      ),
    );
  }

  // ---- step 2 · age ---------------------------------------------------------
  Widget _stepAge(Responsive r) {
    return _StepShell(
      headline: 'How old\nare you?',
      accent: 'old',
      sub: 'Rivlr is strictly 18+. Everyone here is an adult.',
      scale: r.scale,
      child: Row(
        children: [
          _roundBtn(Icons.remove_rounded, _age > 18 ? () {
            Buzz.tick();
            setState(() => _age--);
          } : null),
          Expanded(
            child: Center(
              child: Text('$_age', style: T.mono.copyWith(fontSize: 64)),
            ),
          ),
          _roundBtn(Icons.add_rounded, _age < 99 ? () {
            Buzz.tick();
            setState(() => _age++);
          } : null),
        ],
      ),
    );
  }

  // ---- step 3 · identity + meet --------------------------------------------
  Widget _stepIdentity(Responsive r) {
    return _StepShell(
      headline: 'A little\nabout you.',
      accent: 'you',
      sub: 'This is how we match you well.',
      scale: r.scale,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('YOU ARE', style: T.eyebrow),
          const SizedBox(height: 12),
          _chips(_genders, {_gender}, (v) => setState(() => _gender = v)),
          const SizedBox(height: 26),
          Text('YOU WANT TO MEET', style: T.eyebrow),
          const SizedBox(height: 12),
          _chips(_prefs, {_lookingFor}, (v) => setState(() => _lookingFor = v)),
        ],
      ),
    );
  }

  // ---- step 4 · vibes -------------------------------------------------------
  Widget _stepVibes(Responsive r) {
    return _StepShell(
      headline: 'Pick your\nvibe.',
      accent: 'vibe',
      sub: 'What kind of rooms should find you? Pick at least one.',
      scale: r.scale,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final v in _vibeOptions)
            _vibeChip(v[0], v[1], _vibes.contains(v[1]), () {
              Buzz.tick();
              setState(() =>
                  _vibes.contains(v[1]) ? _vibes.remove(v[1]) : _vibes.add(v[1]));
            }),
        ],
      ),
    );
  }

  // ---- pieces ---------------------------------------------------------------
  Widget _roundBtn(IconData icon, VoidCallback? onTap) {
    return Press(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.3 : 1,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
              shape: BoxShape.circle, color: C.glass, border: Border.all(color: C.hair2)),
          child: Icon(icon, color: C.tx),
        ),
      ),
    );
  }

  Widget _chips(List<String> options, Set<String?> selected, ValueChanged<String> onTap) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final o in options)
          Press(
            haptic: false,
            onTap: () {
              Buzz.tick();
              onTap(o);
            },
            child: AnimatedContainer(
              duration: M.quick,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              decoration: BoxDecoration(
                color: selected.contains(o) ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: selected.contains(o) ? Colors.white : C.hair2),
              ),
              child: Text(o,
                  style: T.body.copyWith(
                      color: selected.contains(o) ? Colors.black : C.tx2,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
            ),
          ),
      ],
    );
  }

  Widget _vibeChip(String emoji, String label, bool on, VoidCallback onTap) {
    return Press(
      haptic: false,
      onTap: onTap,
      child: AnimatedContainer(
        duration: M.quick,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: on ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: on ? Colors.white : C.hair2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(label,
                style: T.body.copyWith(
                    color: on ? Colors.black : C.tx2,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

/// Shared page layout — headline with one purple accent word, a sub, the input.
class _StepShell extends StatelessWidget {
  const _StepShell({
    required this.headline,
    required this.accent,
    required this.sub,
    required this.child,
    required this.scale,
  });
  final String headline;
  final String accent;
  final String sub;
  final Widget child;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final parts = headline.split(accent);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 44),
          RichText(
            text: TextSpan(
              style: T.huge(40 * scale),
              children: [
                TextSpan(text: parts.first),
                TextSpan(text: accent, style: const TextStyle(color: C.sig)),
                if (parts.length > 1) TextSpan(text: parts.last),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(sub, style: T.body.copyWith(fontSize: 15, color: C.tx2)),
          const SizedBox(height: 34),
          child,
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
