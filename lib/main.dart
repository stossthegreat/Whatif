import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'core/analytics.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Track.init(); // no-op until Firebase keys are pasted in
  // A build error in release paints Flutter's GREY BOX — a full-screen one
  // looks like the app died. Render black instead (invisible on our black
  // theme) and report the real stack to analytics so it can be fixed.
  ErrorWidget.builder = (details) {
    Track.event('build_error', {
      'err': details.exception.toString().substring(
          0, details.exception.toString().length.clamp(0, 90)),
    });
    return const ColoredBox(color: Color(0xFF060709));
  };
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    Track.event('flutter_error', {
      'err': details.exception.toString().substring(
          0, details.exception.toString().length.clamp(0, 90)),
    });
  };
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const RivlrApp());
}
