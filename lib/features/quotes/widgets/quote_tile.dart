import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/quote.dart';
import '../../favorites/favorites_providers.dart';

/// A quote row with a favourite heart, used by Library and Favorites.
class QuoteTile extends ConsumerWidget {
  const QuoteTile({super.key, required this.quote});

  final Quote quote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isFavorite = ref.watch(
      favoritesProvider.select((ids) => ids.contains(quote.id)),
    );

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: theme.colorScheme.surfaceContainerHighest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: () => context.push(AppRoutes.quotePath(quote.id)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quote.text,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style:
                          AppTheme.quoteStyle(context).copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${quote.author} - ${quote.categoryLabel}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip:
                    isFavorite ? 'Remove from favorites' : 'Add to favorites',
                icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                color: isFavorite ? theme.colorScheme.primary : null,
                onPressed: () =>
                    ref.read(favoritesProvider.notifier).toggle(quote.id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
