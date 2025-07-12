import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/side_navbar.dart';
import '../widgets/patient_assignment_tab.dart';
import '../widgets/users_management_tab.dart';
import '../widgets/reports_tab.dart';
import '../screens/setting_screen.dart';
import '../screens/admin_dashboard.dart';
import '../screens/visits_screen.dart';

/// Centralised route names used by the sidebar navigation.
const Map<int, String> _routeMap = {
  0: '/dashboard',
  1: '/patients',
  2: '/visits',
  3: '/users',
  4: '/reports',
  5: '/settings',
};

/// AdminShell keeps SideNavbar alive and only swaps center content using IndexedStack.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;

  // Helper widgets for inner content per tab, not const due to DashboardBody
  final List<Widget> _pages = [
    DashboardBody(),
    const PatientAssignmentTab(),
    const VisitsScreen(),
    const UsersManagementTab(),
    const ReportsTab(),
    const SettingScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: LayoutBuilder(
        builder: (context, constraints) {
          final stack = IndexedStack(
            index: _selectedIndex,
            children: _pages,
          );
          if (constraints.maxWidth >= 1100) {
            return Row(
              children: [
                SideNavbar(
                  selectedIndex: _selectedIndex,
                  onItemSelected: (i) => setState(() => _selectedIndex = i),
                ),
                Expanded(child: stack),
              ],
            );
          }
          return stack;
        },
      ),
    );
  }
}

/// DashboardBody uses AdminDashboard's _buildBody logic for reuse in stacked shell.
class DashboardBody extends StatelessWidget {
  const DashboardBody({super.key});
  @override
  Widget build(BuildContext context) {
    return AdminDashboard(embedded: true);
  }
}
