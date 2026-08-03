import 'package:flutter/material.dart';
import '../net/api_client.dart';
import '../theme/tokens.dart';
import 'identity_orb.dart';

/// A person: their photo if they have one, their glow orb if they don't.
/// Used everywhere a face-at-rest appears — lists, profiles, chats, rails.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.hue, this.photoId, this.size = 44, this.ring, this.live = false});
  final double hue;
  final int? photoId;
  final double size;
  final Color? ring;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final id = photoId;
    if (id == null || !Api.ready) {
      return IdentityOrb(hue: hue, size: size, ring: ring, live: live);
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: ring ?? Colors.white.withOpacity(0.16),
              width: ring != null ? 2.5 : 1.4,
            ),
          ),
          child: ClipOval(
            child: Image.network(
              Api.mediaUrl(id),
              fit: BoxFit.cover,
              width: size,
              height: size,
              // any load failure → the orb, silently
              errorBuilder: (_, _, _) => IdentityOrb(hue: hue, size: size, ring: ring),
            ),
          ),
        ),
        if (live)
          Positioned(
            right: 0, bottom: 0,
            child: Container(
              width: size * 0.24, height: size * 0.24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: C.acid,
                border: Border.all(color: Colors.black, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
