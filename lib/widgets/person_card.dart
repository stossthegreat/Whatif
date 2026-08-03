import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 'avatar.dart';
import 'glass.dart';

/// One person in the Explore grid.
///
/// Square, photo-first, with the honest signals stacked at the bottom: their
/// handle, whether they're free right now, and what you actually have in
/// common. The shared-interest chip is the point — it turns a wall of
/// strangers into a wall of reasons.
class PersonCard extends StatelessWidget {
  const PersonCard({
    super.key,
    required this.name,
    required this.hue,
    this.thumbId,
    this.title,
    this.shared = const [],
    this.busy = false,
    required this.onTap,
  });

  final String name;
  final double hue;
  final int? thumbId;
  final String? title;
  final List<String> shared;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Press(
      haptic: false,
      scale: 0.97,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            color: C.char2,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: C.hair2),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // the face fills the card; the orb is a real fallback, not a gap
              Positioned.fill(
                child: thumbId == null
                    ? Center(child: Avatar(hue: hue, size: 88))
                    : FittedBox(
                        fit: BoxFit.cover,
                        clipBehavior: Clip.hardEdge,
                        child: Avatar(hue: hue, photoId: thumbId, size: 300),
                      ),
              ),
              // legibility grade under the copy
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0x00000000), Color(0xD9000000)],
                    stops: [0.0, 0.45, 1.0],
                  ),
                ),
              ),
              if (busy)
                const Positioned.fill(
                  child: DecoratedBox(decoration: BoxDecoration(color: Color(0x8C000000))),
                ),
              // availability
              Positioned(
                left: 10,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x99000000),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: busy ? C.tx3 : const Color(0xFF3BE07A),
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
              Positioned(
                left: 12,
                right: 12,
                bottom: 11,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('@$name',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: T.body.copyWith(
                            color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                    if (shared.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: C.sig.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: C.sig.withOpacity(0.55)),
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
                          style: T.tiny.copyWith(fontSize: 11)),
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
