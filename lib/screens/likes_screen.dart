import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../core/analytics.dart';
import '../core/haptics.dart';
import '../net/network_client.dart';
import '../theme/tokens.dart';
import '../widgets/glass.dart';
import '../widgets/person_card.dart';
import 'plus_screen.dart';

/// Who wants to meet you again — everyone who said yes to you and is still
/// waiting on your answer.
///
/// Free accounts see the real count behind frosted glass. That number is
/// never inflated: it comes from actual ratings, so the pitch is true.
class LikesScreen extends StatefulWidget {
  const LikesScreen({super.key});

  static void push(BuildContext context) {
    Track.screen('likes');
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LikesScreen()));
  }

  @override
  State<LikesScreen> createState() => _LikesScreenState();
}

class _LikesScreenState extends State<LikesScreen> {
  StreamSubscription<Map<String, dynamic>>? _sub;
  List<_Liker> _people = const [];
  int _count = 0;
  bool _locked = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _sub = NetworkClient.instance.events.listen(_onNet);
    NetworkClient.instance.likesMe();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onNet(Map<String, dynamic> m) {
    if (!mounted || m['t'] != 'likesMe') return;
    setState(() {
      _loaded = true;
      _locked = m['locked'] == true;
      _count = ((m['count'] as num?) ?? 0).toInt();
      _people = ((m['people'] as List?) ?? const [])
          .whereType<Map>()
          .map((p) => _Liker.fromMap(p.cast<String, dynamic>()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Scaffold(
      backgroundColor: C.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(r.gutter, 6, r.gutter, 4),
              child: Row(
                children: [
                  Press(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: C.glass,
                          border: Border.all(color: C.hair)),
                      child: const Icon(Icons.arrow_back_rounded, size: 20, color: C.tx2),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text('Wants to meet you', style: T.display(24)),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(r.gutter, 0, r.gutter, 12),
              child: Text(
                _count == 0
                    ? 'Nobody waiting on you right now.'
                    : '$_count ${_count == 1 ? 'person' : 'people'} said they’d meet you again.',
                style: T.sub.copyWith(fontSize: 13.5),
              ),
            ),
            Expanded(child: _body(r)),
          ],
        ),
      ),
    );
  }

  Widget _body(Responsive r) {
    if (!_loaded) {
      return Center(child: Text('one second…', style: T.tiny));
    }
    if (_count == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 44),
          child: Text(
            'Meet a few people and rate them — the ones who say yes back show '
            'up here.',
            textAlign: TextAlign.center,
            style: T.body.copyWith(fontSize: 14.5, height: 1.5),
          ),
        ),
      );
    }
    if (_locked) return _lockedWall(r);

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(r.gutter, 2, r.gutter, 24),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: _people.length,
      itemBuilder: (context, i) {
        final p = _people[i];
        return PersonCard(
          name: p.name,
          hue: p.hue,
          thumbId: p.thumbId,
          title: p.title,
          country: p.country,
          age: p.age,
          online: p.online,
          onTap: () {
            Buzz.tick();
            NetworkClient.instance.friendRequest(p.uid);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: C.char2,
              content: Text('Asked @${p.name} to be friends',
                  style: T.body.copyWith(color: Colors.white)),
            ));
          },
        );
      },
    );
  }

  /// The hook: real faces, really blurred. Nothing fake behind the glass.
  Widget _lockedWall(Responsive r) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: GridView.builder(
            padding: EdgeInsets.fromLTRB(r.gutter, 2, r.gutter, 24),
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            itemCount: _count.clamp(1, 6),
            itemBuilder: (context, i) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    C.purpleDeep.withOpacity(0.55),
                    C.char2,
                  ],
                ),
                borderRadius: BorderRadius.circular(R.card),
              ),
            ),
          ),
        ),
        Container(color: const Color(0x99000000)),
        Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: r.gutter),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('💜', style: TextStyle(fontSize: 40 * r.scale)),
                const SizedBox(height: 14),
                Text(
                  _count == 1
                      ? '1 person wants to meet you again'
                      : '$_count people want to meet you again',
                  textAlign: TextAlign.center,
                  style: T.display(24 * r.scale),
                ),
                const SizedBox(height: 10),
                Text(
                  'Rivlr+ shows you exactly who — before you decide about them.',
                  textAlign: TextAlign.center,
                  style: T.body.copyWith(fontSize: 14.5, height: 1.45),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 260,
                  child: Cta(
                    label: 'See who',
                    onTap: () => PlusScreen.push(context,
                        reason: 'See everyone who wants to meet you again.'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Liker {
  _Liker(this.uid, this.name, this.hue, this.thumbId, this.title, this.country,
      this.age, this.online);

  factory _Liker.fromMap(Map<String, dynamic> m) => _Liker(
        (m['uid'] as String?) ?? '',
        (m['name'] as String?) ?? 'someone',
        ((m['hue'] as num?) ?? 210).toDouble(),
        (m['thumbId'] as num?)?.toInt(),
        m['title'] as String?,
        m['country'] as String?,
        (m['age'] as num?)?.toInt(),
        m['online'] == true,
      );

  final String uid;
  final String name;
  final double hue;
  final int? thumbId;
  final String? title;
  final String? country;
  final int? age;
  final bool online;
}
