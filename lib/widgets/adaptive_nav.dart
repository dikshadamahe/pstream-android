import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../config/breakpoints.dart';

class AdaptiveNav extends StatelessWidget {
  const AdaptiveNav({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.child,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;

  static const List<_AdaptiveNavDestination> _destinations = [
    _AdaptiveNavDestination(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    _AdaptiveNavDestination(label: 'Search', icon: Icons.search_rounded),
    _AdaptiveNavDestination(
      label: 'My list',
      icon: Icons.bookmark_outline_rounded,
      selectedIcon: Icons.bookmark_rounded,
    ),
    _AdaptiveNavDestination(
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final layoutClass = windowClass(context);

    if (layoutClass == WindowClass.compact) {
      return Scaffold(
        backgroundColor: AppColors.backgroundMain,
        body: child,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: onDestinationSelected,
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.backgroundSecondary,
          selectedItemColor: AppColors.typeEmphasis,
          unselectedItemColor: AppColors.typeSecondary,
          items: _destinations
              .asMap()
              .entries
              .map((MapEntry<int, _AdaptiveNavDestination> e) {
                final bool selected = currentIndex == e.key;
                return BottomNavigationBarItem(
                  icon: Icon(
                    e.value.resolvedIcon(selected),
                    size: AppSpacing.x6,
                  ),
                  label: e.value.label,
                );
              })
              .toList(growable: false),
        ),
      );
    }

    final isExpanded = layoutClass == WindowClass.expanded;
    final railIconSize = isExpanded ? AppSpacing.x8 : AppSpacing.x6;

    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      body: Row(
        children: [
          SafeArea(
            child: NavigationRailTheme(
              data: NavigationRailThemeData(
                minWidth: AppSpacing.x16,
                groupAlignment: -1,
                elevation: 0,
              ),
              child: NavigationRail(
                selectedIndex: currentIndex,
                onDestinationSelected: onDestinationSelected,
                extended: false,
                labelType: NavigationRailLabelType.all,
                backgroundColor: AppColors.backgroundSecondary,
                indicatorColor: AppColors.buttonsToggle,
                leading: const SizedBox(height: AppSpacing.x2),
                selectedIconTheme: IconThemeData(
                  color: AppColors.typeEmphasis,
                  size: railIconSize,
                ),
                unselectedIconTheme: IconThemeData(
                  color: AppColors.typeSecondary,
                  size: railIconSize,
                ),
                selectedLabelTextStyle: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(
                      color: AppColors.typeEmphasis,
                      fontWeight: FontWeight.w600,
                    ),
                unselectedLabelTextStyle: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: AppColors.typeSecondary),
                destinations: _destinations
                    .asMap()
                    .entries
                    .map((MapEntry<int, _AdaptiveNavDestination> e) {
                      return NavigationRailDestination(
                        icon: Icon(e.value.icon),
                        selectedIcon: Icon(e.value.resolvedIcon(true)),
                        label: Text(e.value.label),
                      );
                    })
                    .toList(growable: false),
              ),
            ),
          ),
          const SizedBox(
            width: AppSpacing.x1,
            child: ColoredBox(color: AppColors.utilsDivider),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _AdaptiveNavDestination {
  const _AdaptiveNavDestination({
    required this.label,
    required this.icon,
    this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData? selectedIcon;

  IconData resolvedIcon(bool selected) {
    if (selected && selectedIcon != null) {
      return selectedIcon!;
    }
    return icon;
  }
}
