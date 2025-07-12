import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

// Admin User model
class AdminUser {
  final String uid;
  final String name;
  final String email;
  final String role;
  final String status;
  final DateTime? createdAt;
  final DateTime? lastLogin;
  final String? authProvider;

  AdminUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    this.createdAt,
    this.lastLogin,
    this.authProvider,
  });

  factory AdminUser.fromMap(Map<String, dynamic> data) {
    return AdminUser(
      uid: data['uid'] ?? '',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? '',
      status: data['status'] ?? 'active',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastLogin: (data['lastLogin'] as Timestamp?)?.toDate(),
      authProvider: data['authProvider'],
    );
  }
}

class AdminAuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  GoogleSignIn? _googleSignIn;
  bool _isGoogleSignInAvailable = false;

  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _adminName;
  String? _adminEmail;
  String? _adminRole;

  // Instant performance caching
  static AdminUser? _cachedAdmin;
  static DateTime? _lastCacheTime;
  static const Duration _cacheTimeout = Duration(hours: 24);
  static bool _skipFirebaseQueries = false;

  // Getters
  bool get isAuthenticated => _isAuthenticated;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  String? get adminName => _adminName;

  String? get adminEmail => _adminEmail;

  String? get adminRole => _adminRole;

  bool get isGoogleSignInAvailable => _isGoogleSignInAvailable;

  // For now, treat as configured if initialization succeeded
  bool get isGoogleSignInConfigured => _isGoogleSignInAvailable;

  String? get currentUserUid => _cachedAdmin?.uid;
  
  String? get currentUserName => _adminName;

  AdminAuthService() {
    _initializeAuth();
    // Don't initialize Google Sign-In immediately to avoid startup crashes
    // It will be initialized lazily when needed
  }

  void _initializeAuth() {
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        _handleUserAuthenticated(user);
      } else {
        _resetAuthState();
      }
    });
  }

  Future<void> _initializeGoogleSignIn() async {
    if (_googleSignIn != null) return;

    try {
      if (kIsWeb) {
        // For web, we don't need to initialize GoogleSignIn plugin
        // We'll use Firebase's built-in web authentication
        _isGoogleSignInAvailable = true;
        return;
      }
      
      // For mobile platforms
      _googleSignIn = GoogleSignIn(
        // For Android, it's set in google-services.json
        // For iOS, it's set in GoogleService-Info.plist
        scopes: ['email', 'profile'],
      );
      _isGoogleSignInAvailable = true;
    } catch (e) {
      print('Error initializing Google Sign-In: $e');
      _isGoogleSignInAvailable = false;
      // Provide helpful error message for web
      if (kIsWeb && e.toString().contains('ClientID not set')) {
        print('💡 To fix: Add Google OAuth client ID to web/index.html');
        print(
            '💡 Format: <meta name="google-signin-client_id" content="YOUR_CLIENT_ID">');
      }

      // Don't rethrow the exception to prevent app crashes
    }
  }

  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignIn == null) {
      _initializeGoogleSignIn();
    }
  }

  void _resetAuthState() {
    _isAuthenticated = false;
    _adminName = null;
    _adminEmail = null;
    _adminRole = null;
    notifyListeners();
  }

  Future<void> _handleUserAuthenticated(User user) async {
    // INSTANT authentication - no Firebase delays
    if (_cachedAdmin != null && _cachedAdmin!.uid == user.uid) {
      _setAuthenticatedUser(_cachedAdmin!);
      print('⚡ Instant admin authentication: ${_cachedAdmin!.name}');
      return;
    }

    // Create INSTANT session
    _createInstantSession(user);

    // Load Firebase data in background (non-blocking)
    if (!_skipFirebaseQueries) {
      _loadAdminDataInBackground(user);
    }
  }

  void _createInstantSession(User user) {
    // INSTANT authentication without waiting for Firebase
    _isAuthenticated = true;
    _adminName = user.displayName ?? user.email
        ?.split('@')
        .first ?? 'Admin';
    _adminEmail = user.email;
    _adminRole = 'admin';

    _cachedAdmin = AdminUser(
      uid: user.uid,
      name: _adminName!,
      email: _adminEmail!,
      role: _adminRole!,
      status: 'active',
    );
    _lastCacheTime = DateTime.now();

    print('⚡ INSTANT admin session created: ${user.email}');
    notifyListeners();
  }

  Future<void> _loadAdminDataInBackground(User user) async {
    // Background Firebase load - doesn't block UI
    try {
      final adminDoc = await _firestore
          .collection('admins')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 2));

      if (adminDoc.exists && adminDoc.data() != null) {
        final admin = AdminUser.fromMap(adminDoc.data()!);
        _cachedAdmin = admin;
        _lastCacheTime = DateTime.now();

        if (_isAuthenticated && _adminEmail == admin.email) {
          _setAuthenticatedUser(admin);
          print('✅ Background admin data updated: ${admin.name}');
          notifyListeners();
        }
      }
    } catch (e) {
      print('🔄 Background Firebase load failed (non-blocking): $e');
      // Continue with instant session
    }
  }

  void _setAuthenticatedUser(AdminUser admin) {
    _isAuthenticated = true;
    _adminName = admin.name;
    _adminEmail = admin.email;
    _adminRole = admin.role;
  }

  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final UserCredential result = await _auth
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 5));

      if (result.user != null) {
        // INSTANT session creation
        _createInstantSession(result.user!);

        // Update Firebase in background
        _updateLastLoginInBackground(result.user!.uid);

        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getAuthErrorMessage(e.code);
      _isAuthenticated = false;
    } catch (e) {
      _errorMessage = 'Login failed: ${e.toString()}';
      _isAuthenticated = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final UserCredential result = await _auth
          .createUserWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 5));

      if (result.user != null) {
        // INSTANT session creation
        _isAuthenticated = true;
        _adminName = name;
        _adminEmail = email;
        _adminRole = role;

        _cachedAdmin = AdminUser(
          uid: result.user!.uid,
          name: name,
          email: email,
          role: role,
          status: 'active',
        );
        _lastCacheTime = DateTime.now();

        // Create Firebase document in background
        _createAdminDocumentInBackground(result.user!, name, email, role);

        print('⚡ INSTANT admin account created: $name');
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getAuthErrorMessage(e.code);
      _isAuthenticated = false;
    } catch (e) {
      _errorMessage = 'Signup failed: ${e.toString()}';
      _isAuthenticated = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      User? user;
      
      // For web platform, use Firebase's built-in Google auth directly
      if (kIsWeb) {
        try {
          // Set persistence to LOCAL for better user experience
          await _auth.setPersistence(Persistence.LOCAL);
          
          // Create a Google Auth Provider
          GoogleAuthProvider googleProvider = GoogleAuthProvider();
          googleProvider.addScope('email');
          googleProvider.addScope('profile');
          
          // Try popup method first as it's more reliable for debugging
          try {
            final UserCredential userCredential = await _auth.signInWithPopup(googleProvider);
            user = userCredential.user;
            debugPrint('Google sign-in with popup successful');
          } catch (popupError) {
            debugPrint('Popup auth failed, trying redirect: $popupError');
            
            // Fallback to redirect if popup fails
            await _auth.signInWithRedirect(googleProvider);
            final userCredential = await _auth.getRedirectResult();
            user = userCredential.user;
            debugPrint('Google sign-in with redirect successful');
          }
        } catch (webAuthError) {
          debugPrint('Web auth completely failed: $webAuthError');
          _errorMessage = 'Google sign-in failed: ${webAuthError.toString()}';
          return false;
        }
      } else {
        // Mobile authentication flow
        await _ensureGoogleSignInInitialized();

        if (!_isGoogleSignInAvailable || _googleSignIn == null) {
          _errorMessage = 'Google Sign-In not available on this device';
          notifyListeners();
          return false;
        }

        try {
          final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();

          if (googleUser == null) {
            _errorMessage = 'Sign in canceled by user';
            return false;
          }

          final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

          if (googleAuth.accessToken == null) {
            _errorMessage = 'Failed to get Google access token';
            return false;
          }

          final credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );

          final UserCredential result = await _auth.signInWithCredential(credential);
          user = result.user;
          debugPrint('Google sign-in on mobile successful');
        } catch (mobileAuthError) {
          debugPrint('Mobile auth failed: $mobileAuthError');
          _errorMessage = 'Google sign-in failed: ${mobileAuthError.toString()}';
          return false;
        }
      }

      // If we have a user at this point, authentication succeeded
      if (user != null) {
        // Create session immediately for responsive UI
        _createInstantSession(user);
        
        // Try to create admin document in background, but don't fail if it doesn't work
        try {
          await _createAdminFromGoogleInBackground(user);
        } catch (dbError) {
          // Just log the error but don't fail the sign-in
          debugPrint('Admin document creation failed (non-blocking): $dbError');
        }
        
        return true;
      }
      
      _errorMessage = 'Failed to authenticate with Google';
      return false;
    } catch (e) {
      debugPrint('Google sign-in unexpected error: $e');
      _errorMessage = 'Google sign-in failed: ${e.toString()}';
      _isAuthenticated = false;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        if (_isGoogleSignInAvailable && _googleSignIn != null)
          _googleSignIn!.signOut(),
      ]).timeout(const Duration(seconds: 3));

      _resetAuthState();
      print('✅ Admin signed out successfully');
    } catch (e) {
      print('❌ Sign out error: $e');
      _resetAuthState(); // Force logout
    }
  }

  Future<bool> createSuperAdmin({
    required String name,
    required String email,
    required String password,
  }) async {
    return await signUp(
      name: name,
      email: email,
      password: password,
      role: 'super_admin',
    );
  }

  Future<bool> hasAdminExists() async {
    // Quick check - if cached admin exists, return true
    if (_cachedAdmin != null) return true;

    try {
      final adminsQuery = await _firestore
          .collection('admins')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 2));

      return adminsQuery.docs.isNotEmpty;
    } catch (e) {
      print('🔄 Admin existence check failed: $e');
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Background methods (non-blocking)
  Future<void> _updateLastLoginInBackground(String uid) async {
    try {
      await _firestore.collection('admins').doc(uid).update({
        'lastLogin': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 3));
    } catch (e) {
      print('🔄 Background last login update failed (non-blocking): $e');
    }
  }

  Future<void> _createAdminDocumentInBackground(User user, String name,
      String email, String role) async {
    try {
      await _firestore.collection('admins').doc(user.uid).set({
        'uid': user.uid,
        'name': name,
        'email': email,
        'role': role,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': null,
        'authProvider': 'email',
      }).timeout(const Duration(seconds: 5));

      await user.updateDisplayName(name);
      print('✅ Admin document created in background');
    } catch (e) {
      print('🔄 Background admin document creation failed (non-blocking): $e');
    }
  }

  Future<void> _createAdminFromGoogleInBackground(User user) async {
    try {
      // Create a security rules-compliant admin document
      final adminData = {
        'uid': user.uid,
        'name': user.displayName ?? 'Google User',
        'email': user.email ?? '',
        'role': 'admin', // Default role for Google sign-ups
        'status': 'pending', // Start as pending until verified
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        'authProvider': 'google',
        'photoURL': user.photoURL ?? '',
        'emailVerified': user.emailVerified,
        'phoneNumber': user.phoneNumber ?? '',
        // Additional fields for better user management
        'registrationMethod': 'google',
        'registrationCompleted': true,
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      
      // Use transaction to handle permission issues
      await _firestore.runTransaction((transaction) async {
        // First check if this admin already exists
        final docRef = _firestore.collection('admins').doc(user.uid);
        final docSnapshot = await transaction.get(docRef);
        
        if (docSnapshot.exists) {
          // Admin already exists, just update the lastLogin and other relevant fields
          transaction.update(docRef, {
            'lastLogin': FieldValue.serverTimestamp(),
            'photoURL': user.photoURL ?? '',
            'emailVerified': user.emailVerified,
            'name': user.displayName ?? docSnapshot.data()?['name'] ?? 'Google User',
            'authProvider': 'google',
          });
          
          debugPrint('✅ Google admin login updated in transaction');
        } else {
          // Create new admin document
          transaction.set(docRef, adminData);
          
          // Create a public profile document that has less restrictive permissions
          final profileRef = _firestore.collection('admin_profiles').doc(user.uid);
          transaction.set(profileRef, {
            'uid': user.uid,
            'displayName': user.displayName ?? 'Google User',
            'email': user.email ?? '',
            'photoURL': user.photoURL ?? '',
            'createdAt': FieldValue.serverTimestamp(),
            'isGoogleUser': true,
            'preferences': {
              'theme': 'light',
              'notifications': true,
            }
          });
          
          debugPrint('✅ Google admin document created in transaction');
        }
      }).timeout(const Duration(seconds: 15));
      
    } catch (e) {
      // Don't fail the sign-in process if Firestore operations fail
      debugPrint('🔄 Background Google admin creation failed (non-blocking): $e');
      
      // Try a simpler approach with just the essential fields if transaction failed
      try {
        await _firestore.collection('admin_profiles').doc(user.uid).set({
          'uid': user.uid,
          'displayName': user.displayName ?? 'Google User',
          'email': user.email ?? '',
          'isGoogleUser': true,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).timeout(const Duration(seconds: 5));
        
        debugPrint('✅ Fallback profile created for Google user');
      } catch (fallbackError) {
        debugPrint('❌ Even fallback profile creation failed: $fallbackError');
      }
    }
  }
  
  // Note: Using _createInstantSession instead for session updates

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Admin account not found';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-email':
        return 'Invalid email format';
      case 'user-disabled':
        return 'Account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts. Try again later';
      case 'email-already-in-use':
        return 'Email is already registered';
      case 'weak-password':
        return 'Password is too weak';
      case 'operation-not-allowed':
        return 'Operation not allowed';
      case 'invalid-credential':
        return 'Invalid credentials provided';
      case 'network-request-failed':
        return 'Network error. Check your connection';
      default:
        return 'Authentication failed';
    }
  }

  /// Updates local cached admin name and notifies listeners.
  void updateLocalProfile({String? name, String? email}) {
    if (name != null) _adminName = name;
    if (email != null) _adminEmail = email;
    notifyListeners();
  }
}