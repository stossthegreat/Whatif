import 'package:flutter/material.dart';

/// What kind of thing just happened — decides the icon, the tap target, and
/// (in app.dart, which owns the step machine) where a tap actually routes.
enum ToastKind { friendRequest, message, roomInvite }

/// One popped-in banner: enough to render it AND to know where a tap goes,
/// without the toast queue itself needing a BuildContext.
class AppToast {
  AppToast({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.uid,
    required this.name,
    this.hue = 210,
    this.photoId,
    this.extra,
  });
  final ToastKind kind;
  final String title;
  final String subtitle;
  final String uid;
  final String name; // the person's real name — title is display text, this is data
  final double hue;
  final int? photoId;
  final String? extra; // e.g. a room code, for roomInvite

  IconData get icon => switch (kind) {
        ToastKind.friendRequest => Icons.person_add_alt_1_rounded,
        ToastKind.message => Icons.chat_bubble_rounded,
        ToastKind.roomInvite => Icons.meeting_room_rounded,
      };
}

/// The cross-cutting notification bus — a small popup banner queue any state
/// layer can push into (social, chat) without those layers depending on each
/// other. app.dart renders the current toast and owns the tap-routing, since
/// it's the only place with both a BuildContext and the step machine.
class Notify extends ChangeNotifier {
  Notify._();
  static final Notify instance = Notify._();

  final List<AppToast> queue = [];
  AppToast? get current => queue.isEmpty ? null : queue.first;

  void push(AppToast t) {
    queue.add(t);
    notifyListeners();
  }

  void pop() {
    if (queue.isNotEmpty) queue.removeAt(0);
    notifyListeners();
  }
}
