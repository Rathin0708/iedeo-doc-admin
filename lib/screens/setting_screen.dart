import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/admin_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// SettingScreen provides a placeholder for admin application settings
/// Add custom configuration widgets here in future.
class SettingScreen extends StatefulWidget {
  const SettingScreen({Key? key}) : super(key: key);

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  // Simple local state for demo purposes
  bool _darkMode = false;
  bool _notifications = true;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Section
          Consumer<AdminAuthService>(
            builder: (context, authService, child) {
              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 32),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.red[200],
                        child: Icon(Icons.account_circle, color: Colors
                            .red[700], size: 50),
                      ),
                      const SizedBox(width: 22),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            authService.adminName ?? 'Admin',
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            authService.adminEmail ?? 'admin@email.com',
                            style: const TextStyle(
                                fontSize: 15, color: Colors.grey),
                          ),
                          const SizedBox(height: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('Super Administrator',
                                style: TextStyle(fontSize: 12,
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Row(
            children: [
              Icon(Icons.settings, size: 32, color: Colors.red[600]),
              const SizedBox(width: 8),
              const Text(
                'Application Settings',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),

          _buildSectionHeader('Display'),
          Card(
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              SwitchListTile(
                value: _darkMode,
                title: const Text('Dark Mode'),
                subtitle: const Text('Reduce eye-strain with dark theme'),
                onChanged: (val) {
                  setState(() => _darkMode = val);
                  // TODO: hook into global Theme provider
                },
              ),
            ]),
          ),

          const SizedBox(height: 24),

          _buildSectionHeader('Notifications'),
          Card(
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              SwitchListTile(
                value: _notifications,
                title: const Text('Email Notifications'),
                subtitle:
                const Text('Receive updates about system activity'),
                onChanged: (val) {
                  setState(() => _notifications = val);
                  // TODO: connect to backend/user prefs
                },
              ),
            ]),
          ),

          const SizedBox(height: 24),

          _buildSectionHeader('Account'),
          Card(
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Change Password'),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content:
                      Text('Change Password clicked (not implemented).')));
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Profile'),
                onTap: _showEditProfileDialog,
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title:
                const Text('Logout', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  await Provider.of<AdminAuthService>(context, listen: false)
                      .signOut();
                },
              ),
            ]),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog() {
    final authService = Provider.of<AdminAuthService>(context, listen: false);
    final TextEditingController nameController =
    TextEditingController(text: authService.adminName ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Profile'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isEmpty) return;

                try {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    await user.updateDisplayName(newName);
                    await FirebaseFirestore.instance
                        .collection('admins')
                        .doc(user.uid)
                        .update({'name': newName});

                    // Update provider cache and refresh UI
                    authService.updateLocalProfile(name: newName);
                    setState(() {});

                    if (mounted) Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Profile updated successfully')));
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')));
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
    );
  }
}
