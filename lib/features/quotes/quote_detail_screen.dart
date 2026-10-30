import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/quote.dart';
import 'quote_actions.dart';
import 'quote_providers.dart';

class QuoteDetailScreen extends ConsumerWidget {
  const QuoteDetailScreen({super.key, required this.quoteId});

  final String quoteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotes = ref.watch(allQuotesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Quote')),
      body: quotes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => const Center(
          child: Text('We could not load this quote.'),
        ),
        data: (all) {
          final matches = all.where((quote) => quote.id == quoteId);
          if (matches.isEmpty) {
            return const Center(child: Text('This quote could not be found.'));
          }
          return _DetailBody(quote: matches.first);
        },
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.quote});

  final Quote quote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Card(
          elevation: 0,
          color: scheme.primaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.format_quote_rounded,
                  size: 36,
                  color: scheme.onPrimaryContainer,
                ),
                const SizedBox(height: 8),
                Text(
                  quote.text,
                  style: AppTheme.quoteStyle(context).copyWith(
                    color: scheme.onPrimaryContainer,
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
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (quote.tags.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final tag in quote.tags) Chip(label: Text(tag))],
          ),
        const SizedBox(height: 24),
        Text('About this quote', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        _InfoRow(label: 'Source', value: quote.source),
        _InfoRow(label: 'License', value: quote.license),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => copyQuote(context, quote),
          icon: const Icon(Icons.copy_outlined),
          label: const Text('Copy quote'),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not specified' : value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
