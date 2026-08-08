import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../state/chat.dart';
import '../state/social.dart';
import '../theme/tokens.dart';
import '../screens/notifications_screen.dart';

/// The persistent bell — pending friend requests + unread messages, one
/// number, one tap to the feed. Matches the glass-circle icon language
/// already used for the settings/friends buttons on Home and Profile, so it
/// slots into any screen's existing header row without looking bolted on.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, this.size = 38, this.iconSize = 19});
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([SocialState.instance, ChatStore.instance]),
      builder: (context, _) {
        final n = SocialState.instance.reqCount + ChatStore.instance.unreadTotal;
        return GestureDetector(
          onTap: () {
            Buzz.tick();
            NotificationsScreen.push(context);
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: C.glass, border: Border.all(color: C.hair)),
                child: Icon(Icons.notifications_rounded, size: iconSize, color: C.tx2),
              ),
              if (n > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 16),
                    decoration: const BoxDecoration(
                      color: C.acid,
                      borderRadius: BorderRadius.all(Radius.circular(100)),
                      boxShadow: [BoxShadow(color: C.acidGlow, blurRadius: 8, spreadRadius: -2)],
                    ),
                    child: Text(n > 99 ? '99+' : '$n',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 10, color: Colors.black, fontWeight: FontWeight.w800)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
