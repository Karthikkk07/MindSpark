import 'package:flutter/material.dart';

import '../../core/widgets/placeholder_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderScreen(
        title: 'Favorites',
        icon: Icons.favorite_border,
        message: 'Quotes you save will appear here.',
      );
}
