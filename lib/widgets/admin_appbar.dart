import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Import your admin services:
import '../services/admin_firebase_service.dart';
import '../services/admin_auth_service.dart';

/// Displays the icon, title, and optional subtitle in a row, suitable for centered placement in AppBar
class AdminAppBarCenter extends StatelessWidget {
  final String title;
  final String subtitle;

  const AdminAppBarCenter(
      {super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.admin_panel_settings,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// A reusable custom AppBar widget for the Admin section, showing title,
/// subtitle (optional), and profile/menu actions
class AdminAppBar extends StatelessWidget {
  final String title;
  final String subtitle;

  const AdminAppBar({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon with decorative background
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.admin_panel_settings,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Main title
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const Spacer(),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: () {
              // Trigger data refresh using Provider
              Provider.of<AdminFirebaseService>(context, listen: false)
                  .refreshData();
            },
          ),
          // Profile menu and logout option
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
    );
  }
}
