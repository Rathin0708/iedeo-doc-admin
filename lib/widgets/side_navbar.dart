import 'package:flutter/material.dart';

/// SideNavbar is a reusable sidebar widget with navigation items.
/// You can use this widget on any page (like AdminDashboard) for consistent navigation.
class SideNavbar extends StatelessWidget {
  final int selectedIndex;
  final void Function(int) onItemSelected;

  const SideNavbar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    // List of menu items and icons
    final navItems = [
      {'label': 'Dashboard', 'icon': Icons.dashboard},
      {'label': 'Patients', 'icon': Icons.people_alt},
      {'label': 'Visits', 'icon': Icons.event_note},
      {'label': 'Users', 'icon': Icons.supervisor_account},
      {'label': 'Reports', 'icon': Icons.insert_chart},
      {'label': 'Settings', 'icon': Icons.settings},
    ];

    return Container(
      width: 200,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int index = 0; index < navItems.length; index++)
            _NavItem(
              label: navItems[index]['label'] as String,
              icon: navItems[index]['icon'] as IconData,
              selected: selectedIndex == index,
              onTap: () => onItemSelected(index),
            ),
          const Spacer(),
        ],
      ),
    );
  }
}

/// Private widget for a single navigation item in the sidebar.
class _NavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? Colors.red[50] : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 22, color: selected ? Colors.red[700] : Colors.grey[700]),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.red[800] : Colors.grey[800],
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
