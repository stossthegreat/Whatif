import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // The product is played in the hand, portrait, after dark.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const WhatIfApp());
}
