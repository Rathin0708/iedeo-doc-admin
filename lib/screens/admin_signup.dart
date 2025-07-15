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

class _AdminSignupState extends State<AdminSignup>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedRole = 'super_admin'; // Default to super_admin for first admin
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isFirstAdmin = false;
  bool _acceptedTerms = false; // Track terms acceptance

  // AnimationController/offset for shake feedback (for invalid form)
  AnimationController? _shakeController;
  Animation<double>? _shakeAnimation;

  // Simple password strength calc/cache
  String _passwordStrengthText = '';
  Color? _passwordStrengthColor;

  final List<Map<String, String>> _adminRoles = [
    {'value': 'super_admin', 'label': 'Super Administrator'},
    {'value': 'admin', 'label': 'Administrator'},
    {'value': 'moderator', 'label': 'Moderator'},
  ];

  @override
  void initState() {
    super.initState();
    _checkFirstAdmin();
    // Set up shake animation
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 24)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController!);
    _passwordController.addListener(_updatePasswordStrength);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _shakeController?.dispose();
    super.dispose();
  }

  // Update password strength text/color based on rules
  void _updatePasswordStrength() {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() {
        _passwordStrengthText = '';
        _passwordStrengthColor = null;
      });
      return;
    }
    // Basic criteria (you can upgrade this)
    bool hasMinLength = password.length >= 6;
    bool hasUpper = password.contains(RegExp(r'[A-Z]'));
    bool hasLower = password.contains(RegExp(r'[a-z]'));
    bool hasDigit = password.contains(RegExp(r'[0-9]'));
    bool hasSpecial = password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));
    int score = [hasMinLength, hasUpper, hasLower, hasDigit, hasSpecial]
        .where((t) => t)
        .length;
    if (score <= 2) {
      _passwordStrengthText = 'Weak';
      _passwordStrengthColor = Colors.red;
    } else if (score == 3 || score == 4) {
      _passwordStrengthText = 'Medium';
      _passwordStrengthColor = Colors.yellow[800];
    } else if (score == 5) {
      _passwordStrengthText = 'Strong';
      _passwordStrengthColor = Colors.green;
    }
    setState(() {});
  }

  // Redirect after Google sign up success
  Future<void> _handleGoogleSignUp(AdminAuthService authService) async {
    try {
      // Step 1: Google OAuth
      final user = await authService.googleAuthOnlyForRegistration();
      if (user == null) {
        if (!mounted) return;
        _showErrorDialog("Google Sign-Up failed.");
        return;
      }
      // Step 2: Prompt for user name via dialog
      final String? enteredName = await _promptForName();
      if (!mounted) return;
      if (enteredName == null || enteredName.trim().length < 2) {
        _showErrorDialog("Please enter your full name.");
        await authService.signOut();
        return;
      }
      // Step 3: Finish registration with manual name entry and Google email
      final bool success = await authService.finalizeGoogleSignUp(user, enteredName.trim());
      if (!mounted) return;
      if (success) {
        Navigator.of(context).pushReplacementNamed('/dashboard');
      } else if (authService.errorMessage != null) {
        _showErrorDialog(authService.errorMessage!);
      } else {
        _showErrorDialog('Google authentication failed. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Google Sign-Up failed: ${e.toString()}');
      }
    }
  }
  Future<String?> _promptForName() async {
    String? name;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text("Enter Full Name"),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: "Full Name"),
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            ElevatedButton(
              child: const Text("Continue"),
              onPressed: () {
                name = controller.text;
                Navigator.of(ctx).pop();
              },
            ),
          ],
        );
      },
    );
    return name;
  }


  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate() || !_acceptedTerms) {
      // If form is invalid or terms not accepted, shake container
      if (_shakeController != null && !_shakeController!.isAnimating) {
        _shakeController!.forward(from: 0);
      }
      return;
    }
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
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
    }
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
                onPressed: () {
                  Navigator.of(ctx).pop(); // Close the dialog
                  Navigator.of(context).pop(); // Pop back to login screen
                },
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
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
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
                        AnimatedBuilder(
                          animation: _shakeController!,
                          builder: (context, child) =>
                              Transform.translate(
                                offset: Offset(_shakeAnimation?.value ?? 0, 0),
                                child: child,
                              ),
                          child: Form(
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
                                    // Add more rules if needed
                                    return null;
                                  },
                                ),
                                // Password requirements text
                                Container(
                                  alignment: Alignment.centerLeft,
                                  margin: const EdgeInsets.only(
                                      bottom: 4, top: 2),
                                  child: const Text(
                                    'Password must be at least 6 chars and include lowercase, uppercase, digit, special.',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.black54),
                                  ),
                                ),
                                // Password Strength Meter
                                if (_passwordStrengthText.isNotEmpty)
                                  Row(
                                    children: [
                                      Container(
                                        width: 12, height: 12,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 6),
                                        decoration: BoxDecoration(
                                          color: _passwordStrengthColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      Text(
                                        'Strength: $_passwordStrengthText',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: _passwordStrengthColor),
                                      ),
                                    ],
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
                                          backgroundColor: _acceptedTerms
                                              ? Color(0xFF4CAF7E)
                                              : Colors.grey,
                                          foregroundColor: Colors.white,
                                          elevation: 2,
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius
                                                  .circular(12)),
                                        ),
                                        onPressed: authService.isLoadingNormal
                                            ? null
                                            : _signUp,
                                        child: authService.isLoadingNormal
                                            ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<
                                                Color>(Colors.white),
                                          ),
                                        )
                                            : const Text(
                                          'Create Admin Account',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),

                                const SizedBox(height: 24),

                                // Divider for OR
                                Row(
                                  children: [
                                    Expanded(
                                        child: Divider(
                                            color: Colors.grey[300])),
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
                                        child: Divider(
                                            color: Colors.grey[300])),
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
                                        icon: authService.isLoadingGoogle
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
                                          authService.isLoadingGoogle
                                              ? 'Creating account with Google...'
                                              : 'Sign Up with Google',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        onPressed: authService.isLoadingGoogle
                                            ? null
                                            : () =>
                                            _handleGoogleSignUp(authService),
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
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    child: const Text(
                                      'Already have an account? Login',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ],

                                // Terms and Conditions Checkbox
                                CheckboxListTile(
                                  value: _acceptedTerms,
                                  onChanged: (v) =>
                                      setState(() =>
                                      _acceptedTerms = v ?? false),
                                  controlAffinity: ListTileControlAffinity
                                      .leading,
                                  contentPadding: EdgeInsets.zero,
                                  title: GestureDetector(
                                    onTap: () {
                                      // Show Terms/Privacy in dialog or navigate
                                      showDialog(
                                        context: context,
                                        builder: (_) =>
                                            AlertDialog(
                                              title: const Text(
                                                  'Terms & Privacy'),
                                              content: const Text(
                                                  'Terms of Service & Privacy Policy...'),
                                              actions: [
                                                TextButton(
                                                  child: const Text('Close'),
                                                  onPressed: () =>
                                                      Navigator
                                                          .of(context)
                                                          .pop(),
                                                ),
                                              ],
                                        ),
                                      );
                                    },
                                    child: const Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(text: 'I agree to the '),
                                          TextSpan(
                                            text: 'Terms of Service',
                                            style: TextStyle(
                                                decoration: TextDecoration
                                                    .underline,
                                                color: Colors.blue),
                                          ),
                                          TextSpan(text: ' and '),
                                          TextSpan(
                                            text: 'Privacy Policy',
                                            style: TextStyle(
                                                decoration: TextDecoration
                                                    .underline,
                                                color: Colors.blue),
                                          ),
                                        ],
                                      ),
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ),
                              ],
                            ),
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