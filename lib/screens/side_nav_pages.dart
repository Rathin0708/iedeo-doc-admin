import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/side_navbar.dart';
import '../widgets/patient_assignment_tab.dart';
import '../widgets/users_management_tab.dart';
import '../widgets/reports_tab.dart';
import 'setting_screen.dart';

/// Centralised route names used by the sidebar navigation.
const Map<int, String> _routeMap = {
  0: '/dashboard',
  1: '/patients',
  2: '/visits',
  3: '/users',
  4: '/reports',
  5: '/settings',
};

/// A thin wrapper that renders the `SideNavbar` on wide screens (>=1100px)
/// and the supplied body content. It also handles sidebar navigation via
/// `Navigator.pushReplacementNamed` so each click truly opens a new page.
class _SideScreenWrapper extends StatelessWidget {
  final int selectedIndex;
  final Widget body;

  const _SideScreenWrapper({
    required this.selectedIndex,
    required this.body,
  });

  void _handleNav(BuildContext context, int index) {
    // No-op if already on the requested page
    if (index == selectedIndex) return;
    final String? routeName = _routeMap[index];
    if (routeName != null) {
      Navigator.pushReplacementNamed(context, routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Desktop / wide
          if (constraints.maxWidth >= 1100) {
            return Row(
              children: [
                SideNavbar(
                  selectedIndex: selectedIndex,
                  onItemSelected: (index) => _handleNav(context, index),
                ),
                Expanded(child: body),
              ],
            );
          }
          // Mobile
          return body;
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Individual Pages
// ---------------------------------------------------------------------------

class PatientsScreen extends StatelessWidget {
  const PatientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SideScreenWrapper(
      selectedIndex: 1,
      body: PatientAssignmentTab(),
    );
  }
}

class VisitsScreen extends StatelessWidget {
  const VisitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _SideScreenWrapper(
      selectedIndex: 2,
      body: Center(
        child: Text(
          'Visits screen – not implemented yet',
          style: Theme
              .of(context)
              .textTheme
              .headlineSmall,
        ),
      ),
    );
  }
}

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SideScreenWrapper(
      selectedIndex: 3,
      body: UsersManagementTab(),
    );
  }
}

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SideScreenWrapper(
      selectedIndex: 4,
      body: ReportsTab(),
    );
  }
}

class SettingsPageWithSidebar extends StatelessWidget {
  const SettingsPageWithSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SideScreenWrapper(
      selectedIndex: 5,
      body: SettingScreen(),
    );
  }
}
