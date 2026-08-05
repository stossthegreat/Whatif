import 'package:flutter/material.dart';
import '../net/api_client.dart';
import '../theme/tokens.dart';
import 'glass.dart';

/// Two-letter ISO country code → flag emoji ('GB' → 🇬🇧).
///
/// Real inputs are messier than the spec: phones and older builds hand us
/// 'UK', 'EL', or a full country name. A wrong pair doesn't fail politely —
/// iOS renders two blank boxes on the card — so anything that isn't a known
/// code returns empty and the card simply shows no flag.
String flagEmoji(String? cc) {
  if (cc == null) return '';
  var u = cc.trim().toUpperCase();
  // the profile field is free text, so these are what people actually type
  const alias = {
    'UK': 'GB', 'EN': 'GB', 'ENGLAND': 'GB', 'SCOTLAND': 'GB',
    'WALES': 'GB', 'GREAT BRITAIN': 'GB', 'UNITED KINGDOM': 'GB',
    'USA': 'US', 'UNITED STATES': 'US', 'AMERICA': 'US',
    'UAE': 'AE', 'IRELAND': 'IE', 'EL': 'GR',
  };
  u = alias[u] ?? u;
  if (u.length != 2) return '';
  final a = u.codeUnitAt(0), b = u.codeUnitAt(1);
  if (a < 65 || a > 90 || b < 65 || b > 90) return '';
  return String.fromCharCodes([0x1F1E6 + a - 65, 0x1F1E6 + b - 65]);
}

/// Emoji must never inherit the display face — Righteous has no emoji
/// glyphs, so an inherited family turns flags into blank boxes.
const _emoji = TextStyle(
  fontFamily: 'Apple Color Emoji',
  fontFamilyFallback: ['Apple Color Emoji', 'Noto Color Emoji', 'Segoe UI Emoji'],
  decoration: TextDecoration.none,
);

/// One person in the Explore grid — a full-bleed poster of a face with the
/// two actions that matter underneath it.
///
/// The photo fills the card as a plain rectangle. (It used to be drawn with
/// the circular Avatar widget stretched to fit, which left visible oval
/// edges and dark corners — the single biggest reason the wall looked
/// unfinished.)
class PersonCard extends StatelessWidget {
  const PersonCard({
    super.key,
    required this.name,
    required this.hue,
    this.thumbId,
    this.title,
    this.shared = const [],
    this.busy = false,
    this.country,
    this.age,
    this.onHi,
    this.onMessage,
    this.hero = false,
    this.online = true,
    this.isFriend = false,
    this.requested = false,
    required this.onTap,
  });

  final String name;
  final double hue;
  final int? thumbId;
  final String? title;
  final List<String> shared;
  final bool busy;
  final String? country;
  final int? age;

  /// The primary action. What it MEANS depends on the state the call site
  /// passed in: for a stranger it adds them, for a friend who's free it
  /// rings them. The call site branches on the same booleans, so the label
  /// and the effect can never drift apart.
  final VoidCallback? onHi;

  /// Only offered once you're actually friends — the server refuses DMs
  /// between strangers, so showing it earlier would be a button that lies.
  final VoidCallback? onMessage;

  /// The full-width billboard treatment for the #1 ranked person.
  final bool hero;

  /// Away people can't be rung; the action becomes "Add".
  final bool online;
  final bool isFriend;
  final bool requested;

  final VoidCallback onTap;

  Color get _tint {
    final safe = ((hue % 360) + 360) % 360;
    return Color.lerp(
        C.purpleDeep, HSLColor.fromAHSL(1.0, safe, 0.55, 0.45).toColor(), 0.45)!;
  }

  @override
  Widget build(BuildContext context) {
    final flag = flagEmoji(country);
    final id = thumbId;
    return Press(
      haptic: false,
      scale: 0.98,
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: C.char2,
          borderRadius: BorderRadius.circular(R.card),
          border: Border.all(color: C.hair2),
          boxShadow: [
            BoxShadow(color: _tint.withOpacity(0.22), blurRadius: 18, spreadRadius: -10),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ---- the face: a plain rectangular fill, no circles involved
            if (id != null && Api.ready)
              Image.network(
                Api.mediaUrl(id),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _Placeholder(name: name, tint: _tint),
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : _Placeholder(name: name, tint: _tint),
              )
            else
              _Placeholder(name: name, tint: _tint),

            // ---- one legibility wash, bottom-weighted
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x40000000), Color(0x00000000), Color(0xF2000000)],
                  stops: [0.0, 0.42, 1.0],
                ),
              ),
            ),
            if (busy)
              const Positioned.fill(
                child: DecoratedBox(decoration: BoxDecoration(color: Color(0x73000000))),
              ),

            // ---- status, small and quiet
            Positioned(
              left: 10,
              top: 10,
              child: Row(
                children: [
                  _StatusPill(online: online, busy: busy),
                  if (hero) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: C.acid,
                        borderRadius: BorderRadius.circular(R.chip),
                      ),
                      child: Text('TOP MATCH',
                          style: T.tiny.copyWith(
                              color: Colors.black,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4)),
                    ),
                  ],
                ],
              ),
            ),

            // ---- name, facts, actions
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: T.display(hero ? 26 : 19)),
                      ),
                      if (age != null) ...[
                        const SizedBox(width: 6),
                        Text('$age',
                            style: T.body.copyWith(
                                color: Colors.white,
                                fontSize: hero ? 17 : 14,
                                fontWeight: FontWeight.w700)),
                      ],
                      if (flag.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(flag, style: _emoji.copyWith(fontSize: hero ? 15 : 13)),
                      ],
                    ],
                  ),
                  if (shared.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text('both like ${shared.first}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: T.tiny.copyWith(
                            color: C.acid, fontSize: 11.5, fontWeight: FontWeight.w800)),
                  ] else if (title != null && title!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(title!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: T.tiny.copyWith(color: C.tx2, fontSize: 11.5)),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _primary()),
                      if (isFriend && onMessage != null) ...[
                        const SizedBox(width: 8),
                        _IconAction(
                          icon: Icons.chat_bubble_rounded,
                          onTap: onMessage!,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One clear action that always tells the truth about what happens next:
  /// add a stranger, ring a friend who's actually free, and never offer a
  /// message to someone the server would refuse to deliver to.
  Widget _primary() {
    if (requested) return const _FlatAction(label: 'Requested', muted: true);
    if (isFriend) {
      final free = online && !busy;
      return _FlatAction(
        label: free ? 'Say hi' : 'Friends',
        muted: !free,
        onTap: free ? onHi : null,
      );
    }
    if (busy) return const _FlatAction(label: 'In a room', muted: true);
    return _FlatAction(label: 'Add', onTap: onHi);
  }
}

/// No photo yet — their letter on their own colour. Reads as designed
/// rather than as a missing image.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.name, required this.tint});
  final String name;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    // runes, not [0]: a name starting with an emoji is a surrogate pair, and
    // half of one renders as a broken box
    final t = name.trim();
    final letter =
        t.isEmpty ? '?' : String.fromCharCode(t.runes.first).toUpperCase();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tint, C.char2],
        ),
      ),
      child: Center(
        child: Text(letter,
            style: T.display(54).copyWith(color: Colors.white.withOpacity(0.30))),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.online, required this.busy});
  final bool online;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final live = online && !busy;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x8C000000),
        borderRadius: BorderRadius.circular(R.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: live ? C.acid : C.tx3,
              boxShadow: live ? const [BoxShadow(color: C.acidGlow, blurRadius: 5)] : null,
            ),
          ),
          const SizedBox(width: 5),
          Text(!online ? 'away' : (busy ? 'in a room' : 'free'),
              style: T.tiny.copyWith(
                  color: live ? Colors.white : C.tx2,
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// The card's main button — full-width, flat, quiet until pressed.
class _FlatAction extends StatelessWidget {
  const _FlatAction({required this.label, this.onTap, this.muted = false});
  final String label;
  final VoidCallback? onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: muted ? null : C.gradSig,
        color: muted ? const Color(0x59000000) : null,
        borderRadius: BorderRadius.circular(R.chip),
        border: Border.all(color: muted ? C.hair2 : const Color(0x33FFFFFF)),
      ),
      child: Text(label,
          style: T.body.copyWith(
              color: muted ? C.tx2 : Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800)),
    );
    if (onTap == null) return body;
    return Press(haptic: false, onTap: onTap, child: body);
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Press(
      haptic: false,
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0x59000000),
          borderRadius: BorderRadius.circular(R.chip),
          border: Border.all(color: C.hair2),
        ),
        child: Icon(icon, size: 15, color: Colors.white),
      ),
    );
  }
}
