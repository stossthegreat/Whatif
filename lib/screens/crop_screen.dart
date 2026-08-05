import 'dart:io' show File;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import '../core/haptics.dart';
import '../theme/tokens.dart';
import '../widgets/glass.dart';

/// Position your face in the circle.
///
/// Your photo shows as a circle almost everywhere in Rivlr, and phone photos
/// are rarely framed for one — heads end up cropped off. So the picked image
/// is pannable and zoomable inside the exact circle it will appear in, and
/// what you see is literally what gets uploaded: we capture the framed square
/// off-screen rather than trying to compute a crop rectangle, so there is no
/// way for the preview and the result to disagree.
///
/// Returns the framed PNG bytes, or null if cancelled.
class CropScreen extends StatefulWidget {
  const CropScreen({super.key, required this.file});
  final XFile file;

  static Future<Uint8List?> push(BuildContext context, XFile file) {
    return Navigator.of(context).push<Uint8List>(MaterialPageRoute(
      builder: (_) => CropScreen(file: file),
      fullscreenDialog: true,
    ));
  }

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  final _boundary = GlobalKey();
  final _controller = TransformationController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _use() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final obj = _boundary.currentContext?.findRenderObject();
      if (obj is! RenderRepaintBoundary) throw Exception('no boundary');
      // capture at a fixed output size regardless of the phone's screen: the
      // stage is laid out square, so pixelRatio scales it to 720x720
      final logical = obj.size.width;
      final image = await obj.toImage(pixelRatio: logical <= 0 ? 3 : 720 / logical);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (!mounted) return;
      final bytes = data?.buffer.asUint8List();
      if (bytes == null) {
        setState(() => _busy = false);
        return;
      }
      Buzz.commit();
      Navigator.of(context).pop(bytes);
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final side = MediaQuery.of(context).size.width - r.gutter * 2;
    return Scaffold(
      backgroundColor: C.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(r.gutter, 6, r.gutter, 0),
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
                      child: const Icon(Icons.close_rounded, size: 20, color: C.tx2),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text('Position your photo', style: T.display(22)),
                ],
              ),
            ),
            const Spacer(),
            // the stage IS the output — captured exactly as shown
            Center(
              child: SizedBox(
                width: side,
                height: side,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RepaintBoundary(
                      key: _boundary,
                      child: ColoredBox(
                        color: C.char2,
                        child: InteractiveViewer(
                          transformationController: _controller,
                          minScale: 1,
                          maxScale: 5,
                          clipBehavior: Clip.hardEdge,
                          child: Image.file(
                            File(widget.file.path),
                            fit: BoxFit.cover,
                            width: side,
                            height: side,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                      ),
                    ),
                    // the mask is OUTSIDE the boundary, so it never ends up
                    // baked into the uploaded image
                    IgnorePointer(
                      child: CustomPaint(painter: _CircleMask(), size: Size(side, side)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('drag to move · pinch to zoom',
                style: T.body.copyWith(fontSize: 13.5, color: C.tx2)),
            const Spacer(),
            Padding(
              padding: EdgeInsets.fromLTRB(r.gutter, 0, r.gutter, 20),
              child: Column(
                children: [
                  Cta(label: _busy ? 'One moment…' : 'Use this photo',
                      onTap: _busy ? null : _use),
                  const SizedBox(height: 10),
                  Press(
                    haptic: false,
                    onTap: () { Buzz.tick(); _controller.value = Matrix4.identity(); },
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text('Reset',
                          style: T.body.copyWith(
                              color: C.tx2, fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dims everything outside the circle and rings it, so the framing is
/// obvious without affecting the captured pixels.
class _CircleMask extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = size.width / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(rect),
      Path()..addOval(Rect.fromCircle(center: center, radius: r)),
    );
    canvas.drawPath(outside, Paint()..color = const Color(0xCC000000));
    canvas.drawCircle(
      center,
      r - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = C.sig,
    );
  }

  @override
  bool shouldRepaint(_CircleMask old) => false;
}
