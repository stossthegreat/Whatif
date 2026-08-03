import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/haptics.dart';
import '../net/api_client.dart';
import '../net/image_upload.dart';
import '../state/session.dart';
import '../theme/tokens.dart';
import '../widgets/avatar.dart';
import '../widgets/glass.dart';
import 'onboarding_shell.dart';

/// Profile photo — genuinely optional. The identity orb is a real fallback,
/// not a punishment, so the skip is offered plainly rather than hidden.
class PhotoScreen extends StatefulWidget {
  const PhotoScreen({super.key, required this.onDone, required this.onBack});
  final VoidCallback onDone;
  final VoidCallback onBack;

  @override
  State<PhotoScreen> createState() => _PhotoScreenState();
}

class _PhotoScreenState extends State<PhotoScreen> {
  bool _uploading = false;

  Future<void> _pick() async {
    if (_uploading) return;
    Buzz.tick();
    try {
      // full-res pick — the compression ladder handles sizing
      final x = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (x == null || !mounted) return;
      setState(() => _uploading = true);
      final id = await uploadPickedImage(x, kind: 'avatar');
      if (!mounted) return;
      setState(() {
        _uploading = false;
        if (id != null) AppSession.instance.setPhotoId(id);
      });
      if (id == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: C.char2,
          content: Text(Api.lastUploadError ?? 'photo didn’t upload — try again',
              style: T.body.copyWith(color: Colors.white)),
        ));
      }
    } catch (_) {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSession.instance;
    return OnboardStep(
      step: 6,
      total: 7,
      title: 'Put a face to it?',
      accent: 'face',
      sub: 'Optional — your glow works just as well, and you can add a photo '
          'any time. Nothing explicit: profile photos are moderated.',
      onBack: widget.onBack,
      ctaLabel: s.photoId == null ? 'Skip for now' : 'Continue',
      onCta: widget.onDone,
      child: Center(
        child: Column(
          children: [
            const SizedBox(height: 10),
            Press(
              haptic: false,
              onTap: _pick,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedBuilder(
                    animation: s,
                    builder: (context, _) =>
                        Avatar(hue: s.myHue, photoId: s.photoId, size: 132, ring: C.sig),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: C.black, width: 3),
                      ),
                      child: _uploading
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.black))
                          : const Icon(Icons.camera_alt_rounded,
                              size: 18, color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AnimatedBuilder(
              animation: s,
              builder: (context, _) => Text(
                s.photoId == null ? 'tap to add a photo' : 'looking good ✓',
                style: T.body.copyWith(
                    color: s.photoId == null ? C.tx2 : C.sig,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
