import 'package:flutter/material.dart';
import '../models/identity.dart';
import '../models/room.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'live_pill.dart';
import 'pressable.dart';

/// A live room on the Tonight board. Reads as a warm, occupied place: the game's
/// color bleeds in from the left edge, a stack of player orbs shows who's inside,
/// a fill meter shows how packed it is, and a "friends inside" badge does the
/// FOMO work when it applies.
class RoomCard extends StatelessWidget {
  const RoomCard({super.key, required this.room, this.onJoin});
  final Room room;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    final g = room.game;
    return Pressable(
      onTap: onJoin,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          color: WhatIfColors.glass,
          border: Border.all(color: WhatIfColors.hairline),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [g.colors.first.withOpacity(0.22), WhatIfColors.glass],
            stops: const [0.0, 0.5],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _GameBadge(glyph: g.glyph, colors: g.colors),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(room.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: WhatIfType.h3.copyWith(fontSize: 18)),
                      const SizedBox(height: 3),
                      Text('${g.name} · hosted by @${room.host.handle}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: WhatIfType.caption),
                    ],
                  ),
                ),
                const LivePill(),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _OrbStack(players: room.players),
                const Spacer(),
                if (room.friendsInside > 0) ...[
                  TagChip(
                    label: '${room.friendsInside} friend${room.friendsInside > 1 ? 's' : ''}',
                    icon: Icons.favorite_rounded,
                    color: WhatIfColors.magenta,
                  ),
                  const SizedBox(width: 8),
                ],
                TagChip(
                  label: '${room.count}/${room.capacity}',
                  icon: Icons.person_rounded,
                  color: room.isFull ? WhatIfColors.amber : WhatIfColors.textMed,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GameBadge extends StatelessWidget {
  const _GameBadge({required this.glyph, required this.colors});
  final String glyph;
  final List<Color> colors;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(colors: colors),
        boxShadow: [BoxShadow(color: colors.first.withOpacity(0.5), blurRadius: 18, spreadRadius: -4)],
      ),
      child: Text(glyph, style: const TextStyle(fontSize: 26)),
    );
  }
}

/// Overlapping orbs — the crowd, at a glance.
class _OrbStack extends StatelessWidget {
  const _OrbStack({required this.players, this.max = 5});
  final List<Identity> players;
  final int max;
  @override
  Widget build(BuildContext context) {
    final show = players.take(max).toList();
    final extra = players.length - show.length;
    return SizedBox(
      height: 34,
      width: show.length * 22.0 + 12 + (extra > 0 ? 24 : 0),
      child: Stack(
        children: [
          for (var i = 0; i < show.length; i++)
            Positioned(
              left: i * 22.0,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: show[i].gradient,
                  border: Border.all(color: WhatIfColors.ink, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(show[i].glyph, style: const TextStyle(fontSize: 15)),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: show.length * 22.0,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: WhatIfColors.inkRaised,
                  border: Border.all(color: WhatIfColors.ink, width: 2),
                ),
                alignment: Alignment.center,
                child: Text('+$extra',
                    style: WhatIfType.caption.copyWith(fontWeight: FontWeight.w800, fontSize: 11)),
              ),
            ),
        ],
      ),
    );
  }
}
