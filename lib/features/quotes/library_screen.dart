import 'package:flutter/material.dart';

import '../../core/widgets/placeholder_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderScreen(
        title: 'Quote library',
        icon: Icons.menu_book_outlined,
        message: 'Browse quotes by category and search them here. '
            'Coming in a later step.',
      );
}
