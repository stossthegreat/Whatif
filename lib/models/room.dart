import 'identity.dart';
import 'game.dart';

/// A live room on the "Tonight" board. Rooms are the alive-ness of the app:
/// each has a vibe, a host, a crowd of orbs, and a game in progress.
class Room {
  const Room({
    required this.name,
    required this.host,
    required this.players,
    required this.game,
    required this.capacity,
    required this.energy,
    this.friendsInside = 0,
    this.startingInSeconds,
  });

  final String name;
  final Identity host;
  final List<Identity> players;
  final GameType game;
  final int capacity;
  final double energy; // 0..1, drives the room's aurora
  final int friendsInside;
  final int? startingInSeconds; // if scheduled/prime-time

  int get count => players.length;
  bool get isFull => count >= capacity;
  double get fillRatio => (count / capacity).clamp(0.0, 1.0);
}
