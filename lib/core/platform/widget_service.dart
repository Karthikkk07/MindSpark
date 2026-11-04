import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/quote.dart';

/// Sends quotes to the Android home-screen widget.
abstract class WidgetService {
  Future<void> updateQuotes(List<Quote> quotes);
}

class PlatformWidgetService implements WidgetService {
  static const MethodChannel _channel =
      MethodChannel('com.karthik.mindspark/widget');

  @override
  Future<void> updateQuotes(List<Quote> quotes) async {
    final payload = jsonEncode([
      for (final quote in quotes)
        {
          'id': quote.id,
          'text': quote.text,
          'author': quote.author,
          'category': quote.category,
        },
    ]);
    await _channel.invokeMethod<void>('updateQuotes', {'quotes': payload});
  }
}

final widgetServiceProvider = Provider<WidgetService>(
  (ref) => PlatformWidgetService(),
);
