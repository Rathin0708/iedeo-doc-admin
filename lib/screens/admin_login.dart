import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui'; // For ImageFilter.blur
import '../services/admin_auth_service.dart';
import 'admin_signup.dart';

class AdminLogin extends StatefulWidget {
  const AdminLogin({super.key});

  @override
  State<AdminLogin> createState() => _AdminLoginState();
}

class _AdminLoginState extends State<AdminLogin> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    final authService = Provider.of<AdminAuthService>(context, listen: false);
    final success = await authService.signIn(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!success && authService.errorMessage != null) {
      _showErrorSnackBar(authService.errorMessage!);
    }
  }

  Future<void> _signInWithGoogle() async {
    final authService = Provider.of<AdminAuthService>(context, listen: false);
    
    try {
      // Show a loading indicator
      setState(() {});
      
      // Attempt Google Sign-In
      final success = await authService.signInWithGoogle();

      if (mounted) {
        if (!success && authService.errorMessage != null) {
          // Show specific error message from auth service
          _showErrorSnackBar(authService.errorMessage!);
          
          // Log the error for debugging
          debugPrint('Google Sign-In error: ${authService.errorMessage}');
        } else if (!success) {
          // Generic error message if no specific message is available
          _showErrorSnackBar('Google Sign-In failed. Please try again.');
        }
        // Success message is not needed as the user will be redirected to the dashboard
      }
    } catch (e) {
      if (mounted) {
        // Handle any unexpected exceptions
        _showErrorSnackBar('Google Sign-In failed: ${e.toString()}');
        debugPrint('Google Sign-In exception: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController();
    emailController.text = _emailController.text;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Forgot Password'),
          content: TextField(
            controller: emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final authService = Provider.of<AdminAuthService>(
                    context, listen: false);
                final success = await authService.sendPasswordResetEmail(
                    emailController.text);

                if (success) {
                  _showErrorSnackBar('Password reset email sent successfully');
                } else {
                  _showErrorSnackBar('Failed to send password reset email');
                }

                Navigator.of(context).pop();
              },
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Set background color (as fallback)
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            // Background image stretched to fill the screen
            Positioned.fill(
              child: Image.asset(
                'assets/images/login_bag.jpg',
                fit: BoxFit.cover, // Cover the whole screen
              ),
            ),
            // Add a blur filter to the background
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 7, sigmaY: 6),
                // blur values can be adjusted
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),
            // Optional: add a color overlay for better readability
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(
                    0.1), // Adjust opacity as needed
              ),
            ),
            // Main content (centered login card, scrollable)
            Center(
              child: SingleChildScrollView(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  margin: const EdgeInsets.all(24),
                  child: Card(
                    color: Colors.white.withOpacity(0.40),
                    // Semi-transparent white for frosted effect
                    shadowColor: Colors.transparent,
                    // Remove drop shadow for smoother look
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
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
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.admin_panel_settings,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Admin Panel',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Fast & Secure Login',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Connection Status
                          Consumer<AdminAuthService>(
                            builder: (context, authService, child) {
                              if (authService.errorMessage?.contains(
                                  'timeout') == true ||
                                  authService.errorMessage?.contains(
                                      'network') == true ||
                                  authService.errorMessage?.contains(
                                      'offline') == true) {
                                return Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors.orange[200]!),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.wifi_off,
                                          color: Colors.orange[700], size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Connection issues detected. You can still login with existing accounts.',
                                          style: TextStyle(
                                            color: Colors.orange[800],
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            authService.clearError(),
                                        child: Text(
                                          'Dismiss',
                                          style: TextStyle(
                                            color: Colors.orange[700],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                          // Login Form
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                // Email Field
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    labelText: 'Admin Email',
                                    prefixIcon: const Icon(
                                        Icons.admin_panel_settings),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                          color: Colors.white),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(
                                        0.10), // Semi-transparent field background
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Email is required';
                                    }
                                    if (!RegExp(
                                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                        .hasMatch(value)) {
                                      return 'Enter a valid email';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                // Password Field
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _signIn(),
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
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                          color:Colors.white),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(
                                        0.10), // Semi-transparent field background
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Password is required';
                                    }
                                    return null;
                                  },
                                ),
                                // Forgot Password Button
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _showForgotPasswordDialog,
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.black,
                                    ),
                                    child: const Text('Forgot password?'),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // Login Button
                                Consumer<AdminAuthService>(
                                  builder: (context, authService, child) {
                                    return SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: ElevatedButton(
                                        onPressed: authService.isLoading
                                            ? null
                                            : _signIn,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Color(0xFF4CAF7E),
                                          // Use custom green color: #4CAF7E
                                          foregroundColor: Colors.white,
                                          elevation: 2,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                                12),
                                          ),
                                        ),
                                        child: authService.isLoading
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
                                          'Admin Login',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                                // Google Sign In
                                Consumer<AdminAuthService>(
                                  builder: (context, authService, child) {
                                    // Always show Google Sign-In option
                                    return Column(
                                      children: [
                                        // Divider
                                        Row(
                                          children: [
                                            Expanded(child: Divider(
                                                color: Colors.grey[300])),
                                            Padding(
                                              padding: const EdgeInsets
                                                  .symmetric(horizontal: 16),
                                              child: Text(
                                                'OR',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            Expanded(child: Divider(
                                                color: Colors.grey[300])),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        // Google Sign In Button
                                        Container(
                                          width: double.infinity,
                                          height: 50,
                                          margin: const EdgeInsets.symmetric(
                                              vertical: 4),
                                          decoration: BoxDecoration(
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.grey.withOpacity(
                                                    0.2),
                                                spreadRadius: 1,
                                                blurRadius: 3,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: OutlinedButton.icon(
                                            onPressed: authService.isLoading
                                                ? null
                                                : _signInWithGoogle,
                                            icon: authService.isLoading
                                                ? const SizedBox(
                                              height: 20,
                                              width: 20,
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
                                                  ? 'Signing in with Google...'
                                                  : 'Continue with Google',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              backgroundColor: Colors.white,
                                              side: BorderSide(
                                                  color: Colors.grey[300]!),
                                              foregroundColor: Colors.grey[700],
                                              elevation: 2,
                                              shadowColor: Colors.grey[200],
                                              padding: const EdgeInsets
                                                  .symmetric(
                                                  horizontal: 16, vertical: 12),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius
                                                    .circular(12),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                    );
                                  },
                                ),
                                // Create Account Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: OutlinedButton(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (ctx) => const AdminSignup(),
                                        ),
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: Colors.red[600]!),
                                      foregroundColor: Colors.red[600],
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      'Create Admin Account',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
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
      ),
    );
  }
}