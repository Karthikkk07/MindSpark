import 'package:flutter/material.dart';

import '../../core/widgets/placeholder_screen.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderScreen(
        title: 'Goals',
        icon: Icons.flag_outlined,
        message: 'Your goals and streaks will live here.',
      );
}
