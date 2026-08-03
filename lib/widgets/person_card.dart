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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final flag = flagEmoji(country);
    return Press(
      haptic: false,
      scale: 0.97,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(R.card),
        child: Container(
          decoration: BoxDecoration(
            color: C.char2,
            borderRadius: BorderRadius.circular(R.card),
            border: Border.all(color: C.hair2),
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
              // the purple drown — legibility AND brand in one move
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0x00000000),
                      const Color(0x00000000),
                      C.purpleDeep.withOpacity(0.55),
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
                child: Container(
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
                          color: busy ? C.tx3 : C.acid,
                          boxShadow: busy
                              ? null
                              : const [BoxShadow(color: C.acidGlow, blurRadius: 6)],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(busy ? 'in a room' : 'free now',
                          style: T.tiny.copyWith(
                              color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
              // say hi — the one loud key on the card
              if (!busy && onHi != null)
                Positioned(
                  right: 10,
                  top: 10,
                  child: Press(
                    onTap: onHi,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: C.acid,
                        boxShadow: [BoxShadow(color: C.acidGlow, blurRadius: 12, spreadRadius: -2)],
                      ),
                      child: const Icon(Icons.bolt_rounded, size: 22, color: Colors.black),
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
                          child: Text(name.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: T.display(19)),
                        ),
                        if (age != null) ...[
                          const SizedBox(width: 6),
                          Text('$age',
                              style: T.display(15).copyWith(color: C.tx2)),
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
    );
  }
}
