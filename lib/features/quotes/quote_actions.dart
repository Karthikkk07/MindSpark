import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/quote.dart';

/// Copies a quote with its author and shows a confirmation.
Future<void> copyQuote(BuildContext context, Quote quote) async {
  final messenger = ScaffoldMessenger.of(context);
  await Clipboard.setData(
    ClipboardData(text: '"${quote.text}" - ${quote.author}'),
  );
  messenger.showSnackBar(
    const SnackBar(content: Text('Copied to clipboard')),
  );
}
