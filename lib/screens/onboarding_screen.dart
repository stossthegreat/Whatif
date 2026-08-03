import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/analytics.dart';
import '../core/haptics.dart';
import '../theme/tokens.dart';
import '../widgets/aurora.dart';
import '../widgets/glass.dart';

/// Permission priming — the last screen before the room.
///
/// This used to prime a dialog it never fired: in live mode the screen said
/// "enable camera" and then skipped straight past, leaving iOS to ask cold,
/// mid-match, for camera AND mic at once. A "no" there is permanent and kills
/// the user forever.
///
/// Now the ask happens HERE, at peak intent, with the arrow pointing at the
/// button that triggers it — and a denial routes to Settings instead of a
/// dead end.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _busy = false;
  bool _blocked = false; // permanently denied — only Settings can fix it

  Future<void> _go() async {
    if (_busy) return;
    Buzz.commit();
    setState(() => _busy = true);
    try {
      final res = await [Permission.camera, Permission.microphone].request();
      final denied = res.values.any((s) => s.isPermanentlyDenied);
      Track.event('permissions_asked', {
        'camera': res[Permission.camera]?.isGranted == true ? 1 : 0,
        'mic': res[Permission.microphone]?.isGranted == true ? 1 : 0,
      });
      if (!mounted) return;
      if (denied) {
        setState(() { _busy = false; _blocked = true; });
        return;
      }
    } catch (_) {
      // plugin unavailable (simulator quirks) — never trap the user here
    }
    if (mounted) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Scaffold(
      backgroundColor: C.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Aurora(orbs: 3, opacity: 0.5),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: r.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 2),
                  Text(
                    'Turn on your camera & mic to get started',
                    textAlign: TextAlign.center,
                    style: T.huge(36 * r.scale),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _blocked
                        ? 'Camera access is off. Open Settings → Rivlr and switch '
                            'on Camera and Microphone, then come back.'
                        : 'Rivlr is face to face — it doesn’t work without them. '
                            'Nothing is ever recorded.',
                    textAlign: TextAlign.center,
                    style: T.body.copyWith(fontSize: 16, height: 1.45),
                  ),
                  const Spacer(flex: 2),
                  // the arrow points at the button that fires the real dialog
                  const Icon(Icons.arrow_downward_rounded, size: 34, color: Colors.white),
                  const SizedBox(height: 22),
                  Text('You can change this any time in your device settings.',
                      textAlign: TextAlign.center, style: T.tiny),
                  const SizedBox(height: 12),
                  Cta(
                    label: _blocked
                        ? 'Open Settings'
                        : (_busy ? 'Getting ready…' : 'Continue'),
                    onTap: _blocked
                        ? () => openAppSettings()
                        : (_busy ? null : _go),
                  ),
                  const SizedBox(height: 22),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
