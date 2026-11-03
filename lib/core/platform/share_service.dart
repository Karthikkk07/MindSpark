import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the system share sheet. Implemented natively on Android.
abstract class ShareService {
  Future<void> shareText(String text);
}

class PlatformShareService implements ShareService {
  static const MethodChannel _channel =
      MethodChannel('com.karthik.mindspark/share');

  @override
  Future<void> shareText(String text) async {
    await _channel.invokeMethod<void>('shareText', {'text': text});
  }
}

final shareServiceProvider = Provider<ShareService>(
  (ref) => PlatformShareService(),
);
