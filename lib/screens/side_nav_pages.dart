import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/admin_auth_service.dart';
import '../services/admin_firebase_service.dart';
import '../widgets/side_navbar.dart';
import '../widgets/patient_assignment_tab.dart';
import '../widgets/users_management_tab.dart';
import '../widgets/reports_tab.dart';
import '../screens/setting_screen.dart';
import '../screens/admin_dashboard.dart';
import '../screens/visits_screen.dart';
import '../widgets/admin_appbar.dart';

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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AppBar(
          backgroundColor: const Color(0xFF4CAF7E),
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          flexibleSpace: SafeArea(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Left: menu/drawer button if needed
                Align(
                  alignment: Alignment.centerLeft,
                  child: LayoutBuilder(builder: (context, _) {
                    final screenWidth = MediaQuery
                        .of(context)
                        .size
                        .width;
                    if (screenWidth < 1000) {
                      return IconButton(
                        icon: const Icon(Icons.menu),
                        onPressed: () {
                          _scaffoldKey.currentState?.openDrawer();
                        },
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                ),
                // Center: icon + title + subtitle (centered exactly!)
                Center(
                  child: AdminAppBarCenter(
                    title: _pageTitles[_selectedIndex],
                    subtitle: _selectedIndex == 0
                        ? 'System Management Dashboard'
                        : '',
                  ),
                ),
                // Right: actions (refresh and profile)
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        tooltip: 'Refresh',
                        onPressed: () {
                          Provider.of<AdminFirebaseService>(
                              context, listen: false)
                              .refreshData();
                        },
                      ),
                      Consumer<AdminAuthService>(
                        builder: (context, authService, _) {
                          return PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.account_circle,
                              color: Colors.white,
                              size: 28,
                            ),
                            onSelected: (value) async {
                              if (value == 'logout') {
                                await authService.signOut();
                                Navigator.of(context).pushNamedAndRemoveUntil(
                                  '/',
                                      (route) => false,
                                );
                              }
                            },
                            itemBuilder: (context) =>
                            [
                              PopupMenuItem(
                                enabled: false,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      authService.adminName ?? 'Admin',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const Text(
                                      'Super Administrator',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: 'logout',
                                child: Row(
                                  children: [
                                    Icon(Icons.logout, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text(
                                      'Logout',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
