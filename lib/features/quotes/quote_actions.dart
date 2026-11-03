import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/share_service.dart';
import '../../models/quote.dart';

/// The text used when a quote is copied or shared.
String quoteShareText(Quote quote) => '"${quote.text}" - ${quote.author}';

/// Copies a quote with its author and shows a confirmation.
Future<void> copyQuote(BuildContext context, Quote quote) async {
  final messenger = ScaffoldMessenger.of(context);
  await Clipboard.setData(ClipboardData(text: quoteShareText(quote)));
  messenger.showSnackBar(
    const SnackBar(content: Text('Copied to clipboard')),
  );
}

/// Opens the share sheet, or explains if sharing is not available.
Future<void> shareQuote(
  BuildContext context,
  WidgetRef ref,
  Quote quote,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final service = ref.read(shareServiceProvider);
  try {
    await service.shareText(quoteShareText(quote));
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Sharing is not available on this device')),
    );
  }
}
