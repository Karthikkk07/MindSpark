import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/quote.dart';
import '../favorites/favorites_providers.dart';
import 'quote_actions.dart';

/// Favourite, copy and share buttons for one quote.
class QuoteActionBar extends ConsumerWidget {
  const QuoteActionBar({super.key, required this.quote, this.color});

  final Quote quote;

  /// Icon colour, for use on coloured cards.
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(
      favoritesProvider.select((ids) => ids.contains(quote.id)),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
          icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
          color: color,
          onPressed: () =>
              ref.read(favoritesProvider.notifier).toggle(quote.id),
        ),
        IconButton(
          tooltip: 'Copy quote',
          icon: const Icon(Icons.copy_outlined),
          color: color,
          onPressed: () => copyQuote(context, quote),
        ),
        IconButton(
          tooltip: 'Share quote',
          icon: const Icon(Icons.share_outlined),
          color: color,
          onPressed: () => shareQuote(context, ref, quote),
        ),
      ],
    );
  }
}
