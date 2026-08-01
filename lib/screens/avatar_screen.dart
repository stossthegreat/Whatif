import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../models/identity.dart';
import '../state/app_state.dart';
import '../theme/colors.dart';
import '../theme/motion.dart';
import '../theme/typography.dart';
import '../widgets/aurora_button.dart';
import '../widgets/presence_orb.dart';
import '../widgets/reveal.dart';
import '../widgets/whatif_scaffold.dart';

/// Identity creation — the whole thing fits on one screen and takes ~15 seconds.
/// A big live orb reacts instantly to every choice (glyph, gradient, handle,
/// vibe). No photo, ever: you are a luminous character, not a face to be rated.
/// A "surprise me" die rolls a random combo for the indecisive.
class AvatarScreen extends StatefulWidget {
  const AvatarScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<AvatarScreen> createState() => _AvatarScreenState();
}

class _AvatarScreenState extends State<AvatarScreen> {
  final _rng = math.Random();
  final _handleCtl = TextEditingController();
  int _glyph = 1;
  int _palette = 5;
  int _vibe = 4;

  @override
  void initState() {
    super.initState();
    _handleCtl.text = '';
  }

  @override
  void dispose() {
    _handleCtl.dispose();
    super.dispose();
  }

  Identity get _preview => Identity(
        handle: _handleCtl.text.trim().isEmpty ? 'you' : _handleCtl.text.trim(),
        glyph: Identity.glyphs[_glyph],
        colors: Identity.palettes[_palette],
        vibe: Identity.vibes[_vibe],
      );

  void _surprise() {
    Buzz.commit();
    setState(() {
      _glyph = _rng.nextInt(Identity.glyphs.length);
      _palette = _rng.nextInt(Identity.palettes.length);
      _vibe = _rng.nextInt(Identity.vibes.length);
    });
  }

  void _commit() {
    AppState.instance.updateMe(_preview);
    Buzz.impact();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return WhatIfScaffold(
      energy: 0.5,
      palette: _preview.colors.length >= 2
          ? [_preview.colors[0], _preview.colors[1], WhatIfColors.cyan]
          : WhatIfColors.aurora,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('make your orb', style: WhatIfType.h2),
                _DieButton(onTap: _surprise),
              ],
            ),
            const SizedBox(height: 4),
            Text('this is how the room sees you',
                style: WhatIfType.caption.copyWith(color: WhatIfColors.textLow)),
            const SizedBox(height: 8),

            // Live preview — springs whenever the identity changes.
            Expanded(
              flex: 4,
              child: Center(
                child: _AnimatedPreview(identity: _preview),
              ),
            ),

            // Handle field.
            Reveal(
              child: _HandleField(controller: _handleCtl, onChanged: (_) => setState(() {})),
            ),
            const SizedBox(height: 16),

            // Glyph picker.
            _PickerRow(
              label: 'FACE',
              child: SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: Identity.glyphs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => _ChipChoice(
                    selected: i == _glyph,
                    onTap: () {
                      Buzz.tick();
                      setState(() => _glyph = i);
                    },
                    child: Text(Identity.glyphs[i], style: const TextStyle(fontSize: 24)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Palette picker.
            _PickerRow(
              label: 'AURA',
              child: SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: Identity.palettes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) => _SwatchChoice(
                    colors: Identity.palettes[i],
                    selected: i == _palette,
                    onTap: () {
                      Buzz.tick();
                      setState(() => _palette = i);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Vibe picker.
            _PickerRow(
              label: 'VIBE',
              child: SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: Identity.vibes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => _VibeChoice(
                    label: Identity.vibes[i],
                    selected: i == _vibe,
                    onTap: () {
                      Buzz.tick();
                      setState(() => _vibe = i);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            AuroraButton(label: 'This is me', icon: Icons.check_rounded, onTap: _commit),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _AnimatedPreview extends StatelessWidget {
  const _AnimatedPreview({required this.identity});
  final Identity identity;
  @override
  Widget build(BuildContext context) {
    // TweenAnimationBuilder gives a gentle scale pop whenever the glyph key
    // changes, so swapping face/aura feels responsive.
    return TweenAnimationBuilder<double>(
      key: ValueKey('${identity.glyph}${identity.colors.hashCode}'),
      tween: Tween(begin: 0.86, end: 1.0),
      duration: Motion.base,
      curve: Motion.emphatic,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: PresenceOrb(identity: identity, size: 132, active: true, showLabel: true),
    );
  }
}

class _HandleField extends StatelessWidget {
  const _HandleField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: WhatIfColors.glass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: WhatIfColors.hairlineStrong),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text('@', style: WhatIfType.h3.copyWith(color: WhatIfColors.textLow)),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              maxLength: 14,
              cursorColor: WhatIfColors.cyan,
              style: WhatIfType.h3.copyWith(color: WhatIfColors.textHigh),
              decoration: InputDecoration(
                counterText: '',
                border: InputBorder.none,
                hintText: 'pick a handle',
                hintStyle: WhatIfType.h3.copyWith(color: WhatIfColors.textFaint),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({required this.label, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: WhatIfType.overline.copyWith(color: WhatIfColors.textLow, fontSize: 11)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _ChipChoice extends StatelessWidget {
  const _ChipChoice({required this.child, required this.selected, required this.onTap});
  final Widget child;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.quick,
        curve: Motion.entrance,
        width: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? WhatIfColors.glassStrong : WhatIfColors.glass,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? WhatIfColors.cyan : WhatIfColors.hairline,
            width: selected ? 2 : 1,
          ),
        ),
        child: child,
      ),
    );
  }
}

class _SwatchChoice extends StatelessWidget {
  const _SwatchChoice({required this.colors, required this.selected, required this.onTap});
  final List<Color> colors;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.quick,
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: colors),
          border: Border.all(
            color: selected ? Colors.white : Colors.white.withOpacity(0.15),
            width: selected ? 3 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: colors.first.withOpacity(0.6), blurRadius: 16, spreadRadius: 1)]
              : null,
        ),
      ),
    );
  }
}

class _VibeChoice extends StatelessWidget {
  const _VibeChoice({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.quick,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? WhatIfColors.glassStrong : WhatIfColors.glass,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? WhatIfColors.magenta : WhatIfColors.hairline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(label,
            style: WhatIfType.label.copyWith(
              color: selected ? WhatIfColors.textHigh : WhatIfColors.textMed,
              fontWeight: FontWeight.w700,
            )),
      ),
    );
  }
}

class _DieButton extends StatelessWidget {
  const _DieButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: WhatIfColors.glass,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: WhatIfColors.hairlineStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎲', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 7),
            Text('surprise me',
                style: WhatIfType.label.copyWith(color: WhatIfColors.textHigh, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
