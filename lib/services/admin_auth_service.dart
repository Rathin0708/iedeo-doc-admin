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
  bool _isLoadingNormal = false;
  bool _isLoadingGoogle = false;
  String? _errorMessage;
  String? _adminName;
  String? _adminEmail;
  String? _adminRole;

  // Instant performance caching
  static AdminUser? _cachedAdmin;
  static DateTime? _lastCacheTime;
  static const Duration _cacheTimeout = Duration(hours: 24);
  static final bool _skipFirebaseQueries = false;

  // Prevents repeated/overlapping Google logins
  final bool _googleSignInInProgress = false;
  final bool _lastGoogleSignInCancelled = false;

  bool get isGoogleSignInInProgress => _googleSignInInProgress;

  bool get lastGoogleSignInCancelled => _lastGoogleSignInCancelled;

  // Getters
  bool get isAuthenticated => _isAuthenticated;

  bool get isLoadingNormal => _isLoadingNormal;

  bool get isLoadingGoogle => _isLoadingGoogle;

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
    _isLoadingNormal = true;
    notifyListeners();

    try {
      final UserCredential result = await _auth
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 5));

      if (result.user != null) {
        // ADMIN EMAIL FIRESTORE CHECK
        final emailToCheck = result.user!.email;
        try {
          final querySnapshot = await _firestore
              .collection('admins')
              .where('email', isEqualTo: emailToCheck)
              .limit(1)
              .get();
          if (querySnapshot.docs.isEmpty) {
            // Not an admin
            _errorMessage = 'Account not registered as admin.';

            await signOut();
            _isAuthenticated = false;
            _isLoadingNormal = false;
            notifyListeners();
            return false;
          }
        } catch (e) {
          _errorMessage = 'Unable to verify admin privileges. Try again.';
          await signOut();
          _isAuthenticated = false;
          _isLoadingNormal = false;
          notifyListeners();
          return false;
        }
        // END ADMIN FIRESTORE CHECK

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
      _isLoadingNormal = false;
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
    _isLoadingNormal = true;
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
      _isLoadingNormal = false;
      notifyListeners();
    }
    return false;
  }

  // Shared helper: signs in with Google and returns the User, or null if cancelled/failed.
  Future<User?> _handleGoogleUserAuth() async {
    User? user;
    if (kIsWeb) {
      GoogleAuthProvider googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.addScope('profile');
      final UserCredential userCredential =
      await _auth.signInWithPopup(googleProvider);
      user = userCredential.user;
    } else {
      await _ensureGoogleSignInInitialized();
      if (!_isGoogleSignInAvailable || _googleSignIn == null) {
        return null;
      }
      final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();
      if (googleUser == null) {
        return null;
      }
      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        return null;
      }
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final UserCredential result =
      await _auth.signInWithCredential(credential);
      user = result.user;
    }
    return user;
  }

  /// GOOGLE REGISTRATION UPGRADE: Two-step flow
  /// Step 1: Only run Google Auth, do not write to DB. Caller must prompt for name.
  Future<User?> googleAuthOnlyForRegistration() async {
    return await _handleGoogleUserAuth();
  }

  /// Step 2: Finalize registration with a manual name (not displayName from Google!).
  /// Only called after googleAuthOnlyForRegistration succeeds.
  Future<bool> finalizeGoogleSignUp(User user, String name) async {
    _isLoadingGoogle = true;
    _errorMessage = null;
    notifyListeners();
    try {
      // Check if already registered
      final admins = await _firestore
          .collection('admins')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();
      if (admins.docs.isNotEmpty) {
        _errorMessage = 'This email is already registered.';
        await signOut();
        _isLoadingGoogle = false;
        notifyListeners();
        return false;
      }
      // Register user as admin with manual name input only
      await _firestore.collection('admins').doc(user.uid).set({
        'uid': user.uid,
        'name': name, // Use UI input, not Google provided
        'email': user.email,
        'role': 'admin',
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'authProvider': 'google',
        'lastLogin': FieldValue.serverTimestamp(),
      });
      _createInstantSession(user);
      _isLoadingGoogle = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Google sign-up failed: ${e.toString()}';
      _isLoadingGoogle = false;
      notifyListeners();
      return false;
    }
  }

  /// Google Log-In (Signin as admin via Google; must be an existing admin)
  Future<bool> signInWithGoogleOnly() async {
    _isLoadingGoogle = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final User? user = await _handleGoogleUserAuth();
      if (user == null) {
        _errorMessage = 'Google Sign-In cancelled!';
        notifyListeners();
        _isLoadingGoogle = false;
        return false;
      }
      // Allow login only if email is registered in admins
      final admins = await _firestore
          .collection('admins')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();
      if (admins.docs.isEmpty) {
        _errorMessage = 'Account not registered as admin.';
        await signOut();
        _isLoadingGoogle = false;
        notifyListeners();
        return false;
      }
      // Allow login: no changes in Firestore.
      _createInstantSession(user);
      _isLoadingGoogle = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Google sign-in failed: ${e.toString()}';
      _isLoadingGoogle = false;
      notifyListeners();
      return false;
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
      if (kDebugMode) {
        print(' Admin existence check failed: $e');
      }
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Sends a password reset email to the given email address. Returns true if sent, false if failed.
  Future<bool> sendPasswordResetEmail(String email) async {
    _isLoadingNormal = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      _isLoadingNormal = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getAuthErrorMessage(e.code);
    } catch (e) {
      _errorMessage = 'Reset failed: ${e.toString()}';
    } finally {
      _isLoadingNormal = false;
      notifyListeners();
    }
    return false;
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
  void updateLocalProfile({String? name, String? email, required String phone}) {
    if (name != null) _adminName = name;
    if (email != null) _adminEmail = email;
    notifyListeners();
  }
}