import 'dart:async';
import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../state/notify.dart';
import '../theme/tokens.dart';
import 'avatar.dart';

/// The "something just happened" popup — TikTok/WhatsApp style: slides down
/// from the top over whatever screen is showing, auto-dismisses, tap routes
/// to wherever it's about. app.dart owns showing/hiding one at a time from
/// Notify's queue; this widget only knows how to render and time out.
class NotificationToast extends StatefulWidget {
  const NotificationToast({super.key, required this.toast, required this.onTap, required this.onDismiss});
  final AppToast toast;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  State<NotificationToast> createState() => _NotificationToastState();
}

class _NotificationToastState extends State<NotificationToast> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 4), widget.onDismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.toast;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 8, left: 14, right: 14),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: -1, end: 0),
            duration: M.base,
            curve: Curves.easeOutBack,
            builder: (context, v, child) => Transform.translate(
              // easeOutBack overshoots past 0 on purpose (the little bounce)
              // — fine for a translate offset, but Opacity asserts its value
              // into [0,1], so that one gets clamped. num.clamp() returns
              // num, not double, hence the explicit toDouble().
              offset: Offset(0, v * 90),
              child: Opacity(opacity: (1 + v).clamp(0.0, 1.0).toDouble(), child: child),
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Buzz.tick();
                _timer?.cancel();
                widget.onTap();
              },
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
                decoration: BoxDecoration(
                  color: const Color(0xF2140A1E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: C.hair2),
                  boxShadow: [
                    BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 8)),
                    BoxShadow(color: C.sigGlow, blurRadius: 30, spreadRadius: -14),
                  ],
                ),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Avatar(hue: t.hue, photoId: t.photoId, size: 42),
                        Positioned(
                          right: -3,
                          bottom: -3,
                          child: Container(
                            width: 20,
                            height: 20,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: C.sig,
                              border: Border.fromBorderSide(BorderSide(color: Color(0xFF140A1E), width: 2)),
                            ),
                            child: Icon(t.icon, size: 11, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(t.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: T.body.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14.5)),
                          const SizedBox(height: 2),
                          Text(t.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: T.tiny.copyWith(color: C.tx2, fontSize: 12.5)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded, size: 18, color: C.tx3),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
