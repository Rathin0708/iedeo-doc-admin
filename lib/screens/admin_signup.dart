import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/admin_auth_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart'; // Import the official Google Sign-In button for web

class AdminSignup extends StatefulWidget {
  const AdminSignup({super.key});

  @override
  State<AdminSignup> createState() => _AdminSignupState();
}

class _AdminSignupState extends State<AdminSignup> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedRole = 'super_admin'; // Default to super_admin for first admin
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isFirstAdmin = false;

  final List<Map<String, String>> _adminRoles = [
    {'value': 'super_admin', 'label': 'Super Administrator'},
    {'value': 'admin', 'label': 'Administrator'},
    {'value': 'moderator', 'label': 'Moderator'},
  ];

  @override
  void initState() {
    super.initState();
    _checkFirstAdmin();
  }

  Future<void> _checkFirstAdmin() async {
    final authService = Provider.of<AdminAuthService>(context, listen: false);
    final hasAdmin = await authService.hasAdminExists();
    if (mounted) {
      setState(() {
        _isFirstAdmin = !hasAdmin;
        if (_isFirstAdmin) {
          _selectedRole = 'super_admin'; // Force super admin for first admin
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    final authService = Provider.of<AdminAuthService>(context, listen: false);

    final success = await authService.signUp(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      role: _selectedRole,
    );

    if (!success && authService.errorMessage != null) {
      _showErrorDialog(authService.errorMessage!);
    } else if (success) {
      _showSuccessDialog();
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) =>
          AlertDialog(
            title: const Text('Signup Error'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          AlertDialog(
            title: const Text('Success!'),
            content: const Text(
                'Admin account created successfully. You are now logged in.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Admin Registration'),
        backgroundColor: Color(0xFF4CAF7E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Background image stretched to fill the screen
          Positioned.fill(
            child: Image.asset(
              'assets/images/login_bag.jpg',
              fit: BoxFit.cover, // Cover the whole screen
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 7, sigmaY: 6),
              // blur values can be adjusted
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 450),
              margin: const EdgeInsets.all(24),
              child: Card(
                color: Colors.white.withOpacity(0.40),
                // Semi-transparent for frosted effect
                shadowColor: Colors.transparent,
                // Remove shadow for frosted look
                elevation: 0,
                // Remove elevation to prevent shadow
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Container(
                          height: 80,
                          width: 80,
                          decoration: BoxDecoration(  gradient: LinearGradient(
                            colors: [
                              Colors.greenAccent,
                              Colors.green[300]!
                            ],
                          ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.person_add,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _isFirstAdmin
                              ? 'Setup First Admin'
                              : 'Create Admin Account',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isFirstAdmin
                              ? 'Create the first administrator account'
                              : 'Register new administrator',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Signup Form
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              // Name Field
                              TextFormField(
                                controller: _nameController,
                                textCapitalization: TextCapitalization.words,
                                decoration: InputDecoration(
                                  labelText: 'Full Name',
                                  prefixIcon: const Icon(Icons.person),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(
                                      0.10), // Transparent field
                                ),
                                validator: (value) {
                                  if (value == null || value
                                      .trim()
                                      .isEmpty) {
                                    return 'Name is required';
                                  }
                                  if (value
                                      .trim()
                                      .length < 2) {
                                    return 'Name must be at least 2 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),

                              // Email Field
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: 'Email Address',
                                  prefixIcon: const Icon(Icons.email),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(
                                      0.10), // Transparent field
                                ),
                                validator: (value) {
                                  if (value == null || value
                                      .trim()
                                      .isEmpty) {
                                    return 'Email is required';
                                  }
                                  if (!RegExp(
                                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                      .hasMatch(value)) {
                                    return 'Enter a valid email address';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),

                              // Role Selection - disabled for first admin
                              DropdownButtonFormField<String>(
                                value: _selectedRole,
                                decoration: InputDecoration(
                                  labelText: 'Admin Role',
                                  prefixIcon: const Icon(
                                      Icons.admin_panel_settings),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(
                                      0.10), // Transparent field
                                ),
                                items: _adminRoles
                                    .map((role) =>
                                    DropdownMenuItem<String>(
                                      value: role['value'],
                                      child: Text(role['label']!),
                                    ))
                                    .toList(),
                                onChanged: _isFirstAdmin ? null : (value) {
                                  setState(() {
                                    _selectedRole = value!;
                                  });
                                },
                              ),
                              const SizedBox(height: 20),

                              // Password Field
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                    onPressed: () =>
                                        setState(() =>
                                        _obscurePassword = !_obscurePassword),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(
                                      0.10), // Transparent field
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Password is required';
                                  }
                                  if (value.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),

                              // Confirm Password Field
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirmPassword,
                                decoration: InputDecoration(
                                  labelText: 'Confirm Password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                    onPressed: () =>
                                        setState(() =>
                                        _obscureConfirmPassword =
                                        !_obscureConfirmPassword),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(
                                      0.10), // Transparent field
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please confirm your password';
                                  }
                                  if (value != _passwordController.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),

                              // Signup Button
                              Consumer<AdminAuthService>(
                                builder: (context, authService, child) {
                                  return SizedBox(

                                    width: double.infinity,
                                    height: 50,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Color(0xFF4CAF7E), // Custom green color
                                          foregroundColor: Colors.white,
                                          elevation: 2,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        onPressed: authService.isLoading ? null : _signUp,
                                        child: authService.isLoading
                                            ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                            : const Text(
                                          'Create Admin Account',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      )

                                  );
                                },
                              ),

                              const SizedBox(height: 24),

                              // Divider for OR
                              Row(
                                children: [
                                  Expanded(
                                      child: Divider(color: Colors.grey[300])),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    child: Text(
                                      'OR',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                      child: Divider(color: Colors.grey[300])),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Google Sign Up Button (all platforms)
                              Consumer<AdminAuthService>(
                                builder: (context, authService, child) {
                                  return Container(
                                    width: double.infinity,
                                    height: 50,
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 4),
                                    decoration: BoxDecoration(
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.2),
                                          spreadRadius: 1,
                                          blurRadius: 3,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: OutlinedButton.icon(
                                      icon: authService.isLoading
                                          ? const SizedBox(
                                        width: 20, height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                          : Image.asset(
                                        'assets/images/google_logo.png',
                                        height: 24,
                                        width: 24,
                                      ),
                                      label: Text(
                                        authService.isLoading
                                            ? 'Creating account with Google...'
                                            : 'Sign Up with Google',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      onPressed: authService.isLoading
                                          ? null
                                          : () async {
                                        try {
                                          // Show loading state
                                          setState(() {});

                                          // Trigger Google sign-in/signup for all platforms
                                          bool success = await authService
                                              .signInWithGoogle();

                                          if (mounted) {
                                            if (success) {
                                              // Navigate directly to dashboard instead of showing success dialog
                                              // No need to do anything as the AuthWrapper will automatically redirect
                                              // when authService.isAuthenticated becomes true
                                              debugPrint(
                                                  'Google Sign-Up successful - redirecting to dashboard');
                                            } else
                                            if (authService.errorMessage !=
                                                null) {
                                              _showErrorDialog(
                                                  authService.errorMessage!);
                                              debugPrint(
                                                  'Google Sign-Up error: ${authService
                                                      .errorMessage}');
                                            } else {
                                              _showErrorDialog(
                                                  'Google authentication failed. Please try again.');
                                            }
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            _showErrorDialog(
                                                'Google Sign-Up failed: ${e
                                                    .toString()}');
                                            debugPrint(
                                                'Google Sign-Up exception: $e');
                                          }
                                        }
                                      },
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        side: BorderSide(
                                            color: Colors.grey[300]!),
                                        foregroundColor: Colors.grey[700],
                                        elevation: 2,
                                        shadowColor: Colors.grey[200],
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                              12),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),

                              const SizedBox(height: 20),

                              // Back to Login - only show if not first admin
                              if (!_isFirstAdmin) ...[
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text(
                                    'Already have an account? Login',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}