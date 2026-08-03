import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/haptics.dart';
import '../core/sound.dart';
import '../net/api_client.dart';
import '../net/image_upload.dart';
import '../net/network_client.dart';
import '../state/session.dart';
import '../theme/tokens.dart';
import '../widgets/aurora.dart';
import '../widgets/avatar.dart';
import '../widgets/glass.dart';
import 'edit_profile_screen.dart';

/// Onboarding that shapes the experience — seven beats, one question each,
/// huge type, zero clutter:
///   1 · your name        (identity — pick or shuffle a handle)
///   2 · your age         (18+ gate)
///   3 · you / meet       (the matchmaking signal)
///   4 · your vibe        (what kind of rooms find you)
///   5 · your face        (photo — skippable, the orb is a fine identity)
///   6 · where + words    (city/country + languages — matchmaking signals)
///   7 · looking + into   (what you want + interests)
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
  // identity v2
  final _cityCtl = TextEditingController();
  final _countryCtl = TextEditingController();
  final Set<String> _langs = {'English'};
  final Set<String> _looking = {};
  final Set<String> _interests = {};
  bool _photoUploading = false;

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

  static const _lastStep = 6;

  bool _canAdvance() => switch (_step) {
        0 => _handleOk,
        1 => _age >= 18,
        2 => _gender != null,
        3 => _vibes.isNotEmpty,
        _ => true, // photo / place / interests are welcome but never a wall
      };

  void _next() {
    if (!_canAdvance()) return;
    Buzz.commit();
    Sfx.pop();
    FocusScope.of(context).unfocus();
    if (_step < _lastStep) {
      _page.animateToPage(_step + 1,
          duration: M.base, curve: M.ease);
    } else {
      final s = AppSession.instance;
      s.setHandle(_handleCtl.text);
      s.setProfile(
        age: _age,
        gender: _gender,
        lookingFor: _lookingFor,
        vibes: _vibes.toList(),
      );
      s.setIdentityDetails(
        city: _cityCtl.text.trim(),
        country: _countryCtl.text.trim(),
        languages: _langs.toList(),
        lookingForChips: _looking.toList(),
        interests: _interests.toList(),
      );
      NetworkClient.instance.setProfile({
        'age': _age,
        'city': _cityCtl.text.trim(),
        'country': _countryCtl.text.trim(),
        'languages': _langs.toList(),
        'lookingFor': _looking.toList(),
        'interests': _interests.toList(),
      });
      widget.onDone();
    }
  }

  Future<void> _pickPhoto() async {
    if (_photoUploading) return;
    Buzz.tick();
    try {
      // full-res pick — the compression ladder owns sizing (any photo fits)
      final x = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (x == null || !mounted) return;
      setState(() => _photoUploading = true);
      final id = await uploadPickedImage(x, kind: 'avatar');
      if (!mounted) return;
      setState(() {
        _photoUploading = false;
        if (id != null) AppSession.instance.setPhotoId(id);
      });
    } catch (_) {
      if (mounted) setState(() => _photoUploading = false);
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
    _cityCtl.dispose();
    _countryCtl.dispose();
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
                            value: (_step + 1) / (_lastStep + 1),
                            minHeight: 3,
                            backgroundColor: C.char2,
                            valueColor: const AlwaysStoppedAnimation<Color>(C.sig),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text('${_step + 1}/${_lastStep + 1}', style: T.tiny),
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
                        _stepPhoto(r),
                        _stepWhere(r),
                        _stepInterests(r),
                      ],
                    ),
                  ),
                  Cta(
                    label: _step < _lastStep
                        ? (_step == 4 && AppSession.instance.photoId == null
                            ? 'Skip for now'
                            : 'Continue')
                        : 'Let’s go',
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

  // ---- step 5 · photo (skippable) -------------------------------------------
  Widget _stepPhoto(Responsive r) {
    return _StepShell(
      headline: 'Put a face\nto the vibe.',
      accent: 'face',
      sub: 'Optional — your glow works too. You can add one any time.',
      scale: r.scale,
      child: Center(
        child: AnimatedBuilder(
          animation: AppSession.instance,
          builder: (context, _) {
            final s = AppSession.instance;
            return Press(
              haptic: false,
              onTap: _pickPhoto,
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Avatar(hue: s.myHue, photoId: s.photoId, size: 132, ring: C.sig),
                      Positioned(
                        right: 0, bottom: 0,
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: C.black, width: 3),
                          ),
                          child: _photoUploading
                              ? const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.black))
                              : const Icon(Icons.camera_alt_rounded,
                                  size: 18, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    s.photoId == null ? 'tap to add a photo' : 'looking good ✓',
                    style: T.sub.copyWith(
                        color: s.photoId == null ? C.tx2 : C.sig,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ---- step 6 · where + languages -------------------------------------------
  Widget _stepWhere(Responsive r) {
    return _StepShell(
      headline: 'Where in\nthe world?',
      accent: 'world',
      sub: 'Helps us find your people — nothing precise, ever.',
      scale: r.scale,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _miniField(_cityCtl, 'city')),
              const SizedBox(width: 10),
              Expanded(child: _miniField(_countryCtl, 'country')),
            ],
          ),
          const SizedBox(height: 26),
          Text('YOU SPEAK', style: T.eyebrow),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final l in EditProfileScreen.languages)
                _vibeChip('', l, _langs.contains(l), () {
                  Buzz.tick();
                  setState(() => _langs.contains(l) ? _langs.remove(l) : _langs.add(l));
                }),
            ],
          ),
        ],
      ),
    );
  }

  // ---- step 7 · looking for + interests -------------------------------------
  Widget _stepInterests(Responsive r) {
    return _StepShell(
      headline: 'What are you\nhere for?',
      accent: 'here',
      sub: 'Pick what fits — the matches get better with every tap.',
      scale: r.scale,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final l in EditProfileScreen.lookingFor)
                _vibeChip('', l, _looking.contains(l), () {
                  Buzz.tick();
                  setState(() =>
                      _looking.contains(l) ? _looking.remove(l) : _looking.add(l));
                }),
            ],
          ),
          const SizedBox(height: 26),
          Text('YOU’RE INTO', style: T.eyebrow),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final i in EditProfileScreen.interests)
                _vibeChip('', i, _interests.contains(i), () {
                  Buzz.tick();
                  setState(() =>
                      _interests.contains(i) ? _interests.remove(i) : _interests.add(i));
                }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniField(TextEditingController ctl, String hint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.hair2),
      ),
      child: TextField(
        controller: ctl,
        maxLength: 32,
        style: T.body.copyWith(color: Colors.white, fontSize: 15.5),
        decoration: InputDecoration(
          isDense: true,
          counterText: '',
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
          hintText: hint,
          hintStyle: T.body.copyWith(color: C.tx3, fontSize: 15.5),
        ),
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
            if (emoji.isNotEmpty) ...[
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
            ],
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
