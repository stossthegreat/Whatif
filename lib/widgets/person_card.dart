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

/// One person: their face, their name, and the two things you can do about it.
///
/// The actions are two equal frosted pills sitting ON the photo — the shape
/// every good social app has converged on, because a heavy coloured slab
/// reads as an advert and frosted glass reads as part of the picture. Colour
/// is spent on exactly one thing: acid means they are live RIGHT NOW and the
/// button will actually reach them.
class PersonCard extends StatelessWidget {
  const PersonCard({
    super.key,
    required this.name,
    required this.hue,
    this.thumbId,
    this.photoId,
    this.title,
    this.shared = const [],
    this.busy = false,
    this.country,
    this.age,
    this.onHi,
    this.onMessage,
    this.onAdd,
    this.hero = false,
    this.preview = false,
    this.online = true,
    this.isFriend = false,
    this.requested = false,
    required this.onTap,
  });

  final String name;
  final double hue;
  final int? thumbId;

  /// The FULL avatar, used only as a fallback when [thumbId] fails to load.
  final int? photoId;
  final String? title;
  final List<String> shared;
  final bool busy;
  final String? country;
  final int? age;

  /// The live action — ring them into a room. Only reaches someone who is
  /// online and not already busy.
  final VoidCallback? onHi;

  /// Open the thread. Offered only to friends: the server refuses DMs between
  /// strangers, so anywhere else this would be a button that lies.
  final VoidCallback? onMessage;

  /// Send the friend request.
  final VoidCallback? onAdd;

  /// The full-width billboard treatment for the #1 ranked person.
  final bool hero;

  /// "This is you" — your own card, rendered exactly as everyone else sees
  /// it. No actions (you can't follow yourself), and it exists so the one
  /// question a profile photo always raises — does it actually look right to
  /// other people? — has an answer inside the app instead of needing a
  /// second phone.
  final bool preview;

  final bool online;
  final bool isFriend;
  final bool requested;

  final VoidCallback onTap;

  bool get _live => online && !busy;

  Color get _tint {
    final safe = ((hue % 360) + 360) % 360;
    return Color.lerp(
        C.purpleDeep, HSLColor.fromAHSL(1.0, safe, 0.55, 0.45).toColor(), 0.45)!;
  }

  @override
  Widget build(BuildContext context) {
    final flag = flagEmoji(country);
    final id = thumbId;
    final chip = shared.isNotEmpty ? shared.first : (title ?? '');
    return Press(
      haptic: false,
      scale: 0.98,
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: C.char2,
          borderRadius: BorderRadius.circular(R.card),
          boxShadow: [
            BoxShadow(color: _tint.withOpacity(0.18), blurRadius: 18, spreadRadius: -12),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (id != null && Api.ready)
              Image.network(
                Api.mediaUrl(id),
                fit: BoxFit.cover,
                // a dead thumbnail must never mean a faceless card while the
                // full photo is sitting right there — fall through to it
                // before giving up on the letter
                errorBuilder: (_, __, ___) => photoId != null && photoId != id
                    ? Image.network(
                        Api.mediaUrl(photoId!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _Placeholder(name: name, tint: _tint),
                      )
                    : _Placeholder(name: name, tint: _tint),
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : _Placeholder(name: name, tint: _tint),
              )
            else
              _Placeholder(name: name, tint: _tint),

            // one legibility wash, weighted to where the text actually is
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x33000000), Color(0x00000000), Color(0xD9000000)],
                  stops: [0.0, 0.38, 1.0],
                ),
              ),
            ),
            if (busy)
              const Positioned.fill(
                child: DecoratedBox(decoration: BoxDecoration(color: Color(0x66000000))),
              ),

            Positioned(
              left: 9,
              top: 9,
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

            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // name, age and flag read as ONE line — "menace89, 18 🇬🇧"
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(age == null ? name : '$name, $age',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: T.display(hero ? 25 : 18)),
                      ),
                      if (flag.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(flag, style: _emoji.copyWith(fontSize: hero ? 15 : 12.5)),
                      ],
                    ],
                  ),
                  if (chip.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    _Chip(label: chip, accent: shared.isNotEmpty),
                  ],
                  if (!preview) ...[
                    const SizedBox(height: 9),
                    Row(children: _actions()),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Follow and Message, always both — the pair every social card has
  /// converged on, and what people reach for first.
  ///
  /// Message stays honest: the server refuses DMs between strangers, so
  /// until you're connected it's muted and [onMessage] explains why rather
  /// than opening a thread that can't send. The live "say hi" video action
  /// moves onto the status row, where being live is already the subject.
  List<Widget> _actions() {
    final left = requested
        ? const ActionPill(label: 'Requested', muted: true)
        : isFriend
            ? const ActionPill(label: 'Following', muted: true)
            : ActionPill(label: 'Follow', icon: Icons.person_add_alt_1_rounded, onTap: onAdd);

    // always tappable, never muted: a muted pill swallows the tap silently,
    // and "nothing happened" is worse than being told why. The caller
    // explains the follow-first rule when they aren't connected yet.
    final right = ActionPill(
      label: 'Message',
      icon: Icons.chat_bubble_rounded,
      onTap: onMessage,
    );

    return [
      Expanded(child: left),
      const SizedBox(width: 7),
      Expanded(child: right),
    ];
  }
}

/// No photo yet — their letter on their own colour, kept quiet enough that a
/// wall of them still looks composed rather than broken.
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
          colors: [tint.withOpacity(0.85), C.char2],
        ),
      ),
      child: Center(
        child: Text(letter,
            style: T.display(46).copyWith(color: Colors.white.withOpacity(0.16))),
      ),
    );
  }
}

/// A fact about them, frosted onto the photo.
class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.accent = false});
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x2EFFFFFF),
        borderRadius: BorderRadius.circular(R.chip),
      ),
      child: Text(
        accent ? 'both like $label' : label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: T.tiny.copyWith(
            color: accent ? C.acid : Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800),
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
          Text(!online ? 'away' : (busy ? 'in a room' : 'live'),
              style: T.tiny.copyWith(
                  color: live ? Colors.white : C.tx2,
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
