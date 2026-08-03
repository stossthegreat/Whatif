import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 'avatar.dart';
import 'glass.dart';

/// Two-letter ISO country code → flag emoji ('GB' → 🇬🇧). Anything else → ''.
String flagEmoji(String? cc) {
  if (cc == null || cc.length != 2) return '';
  final u = cc.toUpperCase();
  final a = u.codeUnitAt(0), b = u.codeUnitAt(1);
  if (a < 65 || a > 90 || b < 65 || b > 90) return '';
  return String.fromCharCodes([0x1F1E6 + a - 65, 0x1F1E6 + b - 65]);
}

/// One person in the Explore grid — a tall, full-bleed poster of a face.
///
/// The bottom drowns in deep purple; the flag, the NAME in display caps and
/// the age sit on it like a billboard. Top-left: whether they're free right
/// now (acid = alive). Top-right: an acid "say hi" key. The shared-interest
/// chip is the point — it turns a wall of strangers into a wall of reasons.
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
    this.hero = false,
    this.online = true,
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
  final VoidCallback? onHi;

  /// The full-width billboard treatment for the #1 ranked person.
  final bool hero;

  /// Away people (not connected right now) can't be rung — grey dot, no
  /// say-hi key; the tap-through offers Add friend instead.
  final bool online;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final flag = flagEmoji(country);
    // every card carries its person's identity hue — the wall is never a
    // uniform brand color, because the people aren't uniform
    final safeHue = ((hue % 360) + 360) % 360;
    final tint = Color.lerp(
        C.purpleDeep, HSLColor.fromAHSL(1.0, safeHue, 0.55, 0.45).toColor(), 0.4)!;
    return Press(
      haptic: false,
      scale: 0.97,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(R.card),
          boxShadow: [
            BoxShadow(color: tint.withOpacity(0.32), blurRadius: 16, spreadRadius: -8),
          ],
        ),
        child: ClipRRect(
        borderRadius: BorderRadius.circular(R.card),
        child: Container(
          decoration: BoxDecoration(
            color: C.char2,
            borderRadius: BorderRadius.circular(R.card),
            border: Border.all(color: tint.withOpacity(0.5)),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // the face fills the card; the orb is a real fallback, not a gap
              Positioned.fill(
                child: thumbId == null
                    ? Center(child: Avatar(hue: hue, size: 96))
                    : FittedBox(
                        fit: BoxFit.cover,
                        clipBehavior: Clip.hardEdge,
                        child: Avatar(hue: hue, photoId: thumbId, size: 300),
                      ),
              ),
              // the drown — legibility AND identity in one move: brand purple
              // blended toward this person's own hue
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0x00000000),
                      const Color(0x00000000),
                      tint.withOpacity(0.55),
                      const Color(0xE60E0618),
                    ],
                    stops: const [0.0, 0.48, 0.78, 1.0],
                  ),
                ),
              ),
              if (busy)
                const Positioned.fill(
                  child: DecoratedBox(decoration: BoxDecoration(color: Color(0x8C000000))),
                ),
              // availability — acid means someone is actually there
              Positioned(
                left: 10,
                top: 10,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0x99000000),
                        borderRadius: BorderRadius.circular(R.chip),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: online && !busy ? C.acid : C.tx3,
                              boxShadow: online && !busy
                                  ? const [BoxShadow(color: C.acidGlow, blurRadius: 6)]
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(!online ? 'away' : (busy ? 'in a room' : 'free now'),
                              style: T.tiny.copyWith(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    if (hero) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: C.acid,
                          borderRadius: BorderRadius.circular(R.chip),
                          boxShadow: const [
                            BoxShadow(color: C.acidGlow, blurRadius: 10, spreadRadius: -2),
                          ],
                        ),
                        child: Text('★ TOP MATCH',
                            style: T.tiny.copyWith(
                                color: Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6)),
                      ),
                    ],
                  ],
                ),
              ),
              // say hi — the one loud key on the card (only when they can ring)
              if (online && !busy && onHi != null)
                Positioned(
                  right: 10,
                  top: 10,
                  child: Press(
                    onTap: onHi,
                    child: Container(
                      width: hero ? 44 : 38,
                      height: hero ? 44 : 38,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: C.acid,
                        boxShadow: [BoxShadow(color: C.acidGlow, blurRadius: 12, spreadRadius: -2)],
                      ),
                      child: Icon(Icons.bolt_rounded,
                          size: hero ? 25 : 22, color: Colors.black),
                    ),
                  ),
                ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (flag.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(flag, style: const TextStyle(fontSize: 16)),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          // mixed case on purpose — the caps-name wall is
                          // the competition's look
                          child: Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: T.display(hero ? 25 : 18)),
                        ),
                        if (age != null) ...[
                          const SizedBox(width: 6),
                          Text('$age',
                              style: T.display(hero ? 19 : 15).copyWith(color: C.tx2)),
                        ],
                      ],
                    ),
                    if (shared.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: C.sig.withOpacity(0.30),
                          borderRadius: BorderRadius.circular(R.chip),
                          border: Border.all(color: C.sig.withOpacity(0.6)),
                        ),
                        child: Text(shared.first,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: T.tiny.copyWith(
                                color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                      ),
                    ] else if (title != null) ...[
                      const SizedBox(height: 4),
                      Text(title!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: T.tiny.copyWith(color: C.tx2, fontSize: 11)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
