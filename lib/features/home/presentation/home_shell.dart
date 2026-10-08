import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/ui/app_bottom_nav.dart';

/// App container: bottom navigation across Home and the five areas.
/// Each branch keeps its own navigation stack. Labels are kept short so six
/// destinations fit on narrow phones.
class HomeShell extends StatelessWidget {
  const HomeShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: navigationShell,
      // NUEVO: la barra del diseño sustituye a la NavigationBar de Material;
      // la lógica de índice y de ramas es la misma.
      bottomNavigationBar: AppBottomNav(
        selectedIndex: navigationShell.currentIndex,
        onSelected: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        items: [
          AppBottomNavItem(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home,
            label: l.navHome,
          ),
          AppBottomNavItem(
            icon: Icons.chat_bubble_outline,
            selectedIcon: Icons.chat_bubble,
            label: l.navTalk,
          ),
          AppBottomNavItem(
            icon: Icons.school_outlined,
            selectedIcon: Icons.school,
            label: l.navLearn,
          ),
          AppBottomNavItem(
            icon: Icons.menu_book_outlined,
            selectedIcon: Icons.menu_book,
            label: l.navWords,
          ),
          // show_chart no tiene variante rellena: la píldora marca el activo.
          AppBottomNavItem(
            icon: Icons.show_chart,
            selectedIcon: Icons.show_chart,
            label: l.navPath,
          ),
          AppBottomNavItem(
            icon: Icons.person_outline,
            selectedIcon: Icons.person,
            label: l.navProfile,
          ),
        ],
      ),
    );
  }
}
