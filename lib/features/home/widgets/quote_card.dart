import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/quote.dart';
import '../../quotes/quote_action_bar.dart';

/// The main quote card on Home.
class QuoteCard extends StatelessWidget {
  const QuoteCard({
    super.key,
    required this.quote,
    required this.onNewQuote,
  });

  final Quote quote;
  final VoidCallback onNewQuote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: scheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.format_quote_rounded,
              size: 36,
              color: scheme.onPrimaryContainer,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                quote.text,
                style: AppTheme.quoteStyle(context).copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              quote.author,
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            Chip(label: Text(quote.categoryLabel)),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 4,
              children: [
                QuoteActionBar(quote: quote, color: scheme.onPrimaryContainer),
                FilledButton.icon(
                  onPressed: onNewQuote,
                  icon: const Icon(Icons.refresh),
                  label: const Text('New quote'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
