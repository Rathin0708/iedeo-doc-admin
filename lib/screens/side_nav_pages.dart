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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Helper widgets for inner content per tab, not const due to DashboardBody
  final List<Widget> _pages = [
    DashboardBody(),
    const PatientAssignmentTab(),
    const VisitsScreen(),
    const UsersManagementTab(),
    const ReportsTab(),
    const SettingScreen(),
  ];

  // List of page titles that correspond to the navigation items
  final List<String> _pageTitles = [
    'Dashboard',
    'Patients',
    'Visits',
    'Users',
    'Reports',
    'Settings',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey[50],
      // Add AppBar for all screen sizes
      appBar: AppBar(
        title: Text(_pageTitles[_selectedIndex]),
        backgroundColor: const Color(0xFF4CAF7E),
        foregroundColor: Colors.white,
        // Only show the menu button when the drawer is not permanently visible
        leading: LayoutBuilder(builder: (context, _) {
          final screenWidth = MediaQuery.of(context).size.width;
          if (screenWidth < 1000) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                _scaffoldKey.currentState?.openDrawer();
              },
            );
          }
          return const SizedBox.shrink(); // No leading widget when sidebar is visible
        }),
      ),
      // Add drawer for small screens
      drawer: MediaQuery.of(context).size.width < 1000 ? Drawer(
        child: SideNavbar(
          selectedIndex: _selectedIndex,
          onItemSelected: (i) {
            setState(() => _selectedIndex = i);
            // Close the drawer after selection on small screens
            Navigator.pop(context);
          },
        ),
      ) : null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final stack = IndexedStack(
            index: _selectedIndex,
            children: _pages,
          );
          
          // Show side navbar permanently for screens >= 1000px width
          if (constraints.maxWidth >= 1000) {
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
          
          // For smaller screens, just show the content
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
