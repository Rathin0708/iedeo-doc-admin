import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/admin_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_profile_screen.dart';

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
                        backgroundColor: Color(0x5A4CAF7E),
                        child: Icon(Icons.account_circle, color: Color(0xFF4CAF7E), size: 50),
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
                              color: Color(0xFF4CAF7E),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('Super Administrator',
                                style: TextStyle(fontSize: 12,
                                    color:  Colors.white,
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
              Icon(Icons.settings, size: 32, color:  Color(0xFF4CAF7E)),
              const SizedBox(width: 8),
              const Text(
                'Account',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          Card(
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Change Password'),
                onTap: _showChangePasswordDialog,
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
                      .signOut(context: context);
                },
              ),
            ]
            ),
          ),
          const SizedBox(height: 40),
          Center(
            child: Text(
              'App Version: 1.0',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
        ],
      ),

    );
  }

  void _showEditProfileDialog() {
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => EditProfileScreen()));
  }

  /// Displays a dialog for the admin to change their password with proper validation and Firebase interaction.
  void _showChangePasswordDialog() {
    final authService = Provider.of<AdminAuthService>(context, listen: false);
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? authService.adminEmail ?? '';
    final TextEditingController currentPwController = TextEditingController();
    final TextEditingController newPwController = TextEditingController();
    final TextEditingController confirmPwController = TextEditingController();
    ValueNotifier<String?> errorNotifier = ValueNotifier(null);
    ValueNotifier<bool> loading = ValueNotifier(false);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Change Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentPwController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Current Password',
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPwController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: Icon(Icons.vpn_key),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPwController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm New Password',
                      prefixIcon: Icon(Icons.check),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: loading.value
                          ? null
                          : () async {
                        // Show dialog to collect email and send reset link
                        TextEditingController emailController = TextEditingController();
                        ValueNotifier<String?> emailError = ValueNotifier(null);
                        await showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text('Forgot Password'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextField(
                                    controller: emailController,
                                    decoration: const InputDecoration(
                                      labelText: 'Enter your email',
                                      prefixIcon: Icon(Icons.email),
                                    ),
                                    keyboardType: TextInputType.emailAddress,
                                  ),
                                  const SizedBox(height: 8),
                                  ValueListenableBuilder<String?>(
                                    valueListenable: emailError,
                                    builder: (context, val, _) =>
                                    val != null
                                        ? Text(val, style: const TextStyle(
                                        color: Colors.red, fontSize: 12))
                                        : const SizedBox.shrink(),
                                  )
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    final email = emailController.text.trim();
                                    if (email.isEmpty || !email.contains('@')) {
                                      emailError.value = 'Enter a valid email';
                                      return;
                                    }
                                    emailError.value = null;
                                    try {
                                      await FirebaseAuth.instance
                                          .sendPasswordResetEmail(email: email);
                                      if (mounted) Navigator.pop(context);
                                      if (mounted) {
                                        Navigator.pop(
                                          context); // close parent change pw dialog
                                      }
                                      ScaffoldMessenger
                                          .of(context)
                                          .showSnackBar(SnackBar(content: Text(
                                          'Password reset email sent to $email')));
                                    } catch (e) {
                                      emailError.value =
                                      'Failed to send reset: ${e.toString()}';
                                    }
                                  },
                                  child: const Text('Send Reset Link'),
                                )
                              ],
                            );
                          },
                        );
                      },
                      child: const Text('Forgot Password?'),
                    ),
                  ),
                  ValueListenableBuilder<String?>(
                    valueListenable: errorNotifier,
                    builder: (context, val, _) =>
                    val != null ? Text(val, style: TextStyle(color:  Color(0xFF4CAF7E),
                        fontSize: 13)) : SizedBox.shrink(),
                  )
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: loading,
                  builder: (context, loadingVal, _) {
                    return ElevatedButton(
                      onPressed: loadingVal
                          ? null
                          : () async {
                        final currentPw = currentPwController.text.trim();
                        final newPw = newPwController.text.trim();
                        final confirmPw = confirmPwController.text.trim();
                        errorNotifier.value = null;
                        if (currentPw.isEmpty || newPw.isEmpty ||
                            confirmPw.isEmpty) {
                          errorNotifier.value = 'All fields are required';
                          return;
                        }
                        if (newPw != confirmPw) {
                          errorNotifier.value = 'New passwords do not match';
                          return;
                        }
                        if (newPw.length < 8) {
                          errorNotifier.value =
                          'Password must be at least 8 characters';
                          return;
                        }
                        loading.value = true;
                        try {
                          // Re-authenticate admin
                          final cred = EmailAuthProvider.credential(
                              email: email, password: currentPw);
                          await user?.reauthenticateWithCredential(cred);
                          await user?.updatePassword(newPw);
                          if (mounted) Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Password updated successfully')),
                          );
                        } on FirebaseAuthException catch (e) {
                          if (e.code == 'wrong-password') {
                            errorNotifier.value = 'Incorrect current password';
                          } else if (e.code == 'weak-password') {
                            errorNotifier.value = 'New password is too weak';
                          } else {
                            errorNotifier.value =
                            'Error: ${e.message ?? e.code}';
                          }
                        } catch (e) {
                          errorNotifier.value = 'Failed: ${e.toString()}';
                        } finally {
                          loading.value = false;
                        }
                      },
                      child: loadingVal
                          ? SizedBox(width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                          : const Text('Save'

                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

}
