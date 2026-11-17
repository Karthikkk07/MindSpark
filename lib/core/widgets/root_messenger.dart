import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lets code outside the widget tree show a SnackBar (for example when a push
/// arrives while the app is open). Passed to MaterialApp.scaffoldMessengerKey.
final rootMessengerKeyProvider = Provider<GlobalKey<ScaffoldMessengerState>>(
  (ref) => GlobalKey<ScaffoldMessengerState>(),
);
