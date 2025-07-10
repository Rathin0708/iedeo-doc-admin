import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import 'dart:async';
import '../models/admin_user.dart';
import '../models/admin_patient.dart';
import 'package:intl/intl.dart'; // For parsing fallback formatted dates if needed

class AdminFirebaseService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  List<AdminUser> _pendingUsers = [];
  List<AdminUser> _allUsers = [];
  List<AdminPatient> _unassignedPatients = [];
  List<AdminPatient> _allPatients = [];
  Map<String, dynamic> _dashboardStats = {};
  Map<String, dynamic> _reportData = {};
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<AdminUser> get pendingUsers => _pendingUsers;
  List<AdminUser> get allUsers => _allUsers;
  List<AdminPatient> get unassignedPatients => _unassignedPatients;

  List<AdminPatient> get allPatients => _allPatients;

  Map<String, dynamic> get dashboardStats => _dashboardStats;

  Map<String, dynamic> get reportData => _reportData;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AdminFirebaseService() {
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    _setLoading(true);
    try {
      await Future.wait([
        _loadPendingUsers(),
        _loadAllUsers(),
        _loadUnassignedPatients(),
        _loadAllPatients(),
        _loadDashboardStats(),
        _loadReportData(),
      ]);
    } catch (e) {
      _errorMessage = 'Failed to load data: $e';
      print('❌ Error loading initial data: $e');
    } finally {
      _setLoading(false);
    }
  }

  // LEAD ENTRY FUNCTIONS
  Future<bool> addPatientReferral({
    required String patientName,
    required int age,
    required String contactInfo,
    required String address,
    required String problem,
    required String preferredTime,
    required String doctorId,
    required String doctorName,
    String? notes,
    List<Uint8List>? prescriptionImages,
    DateTime? preferredDateTime,
  }) async {
    // Use provider-style loading indicator so UI can react globally
    _setLoading(true);
    try {
      // STEP 1: Upload all prescription images concurrently (if any)
      List<String> prescriptionImageUrls = [];

      if (prescriptionImages != null && prescriptionImages.isNotEmpty) {
        final uploadFutures = prescriptionImages
            .asMap()
            .entries
            .map((entry) => _uploadImageWithRetry(entry.value, entry.key));
        prescriptionImageUrls = await Future.wait(uploadFutures);
      }

      // STEP 2: Create referral document in Firestore
      final patientData = {
        'patientName': patientName,
        'age': age,
        'contactInfo': contactInfo,
        'address': address,
        'problem': problem,
        'preferredTime': preferredTime,
        'doctorId': doctorId,
        'doctorName': doctorName,
        'notes': notes ?? '',
        'prescriptionImages': prescriptionImageUrls,
        'status': 'pending_assignment',
        'therapistId': null,
        'therapistName': null,
        'createdAt': FieldValue.serverTimestamp(),
        // Client-side timestamp helps with local ordering before server timestamp resolves
        'createdAtLocal': Timestamp.now(),
        'updatedAt': FieldValue.serverTimestamp(),
        'visitHistory': [],
        'currentStatus': 'Referred',
        'priority': 'Normal',
        'estimatedCost': 1800, // Default cost per visit
      };
      if (preferredDateTime != null) {
        patientData['preferredDateTime'] =
            Timestamp.fromDate(preferredDateTime);
      }
      await _firestore.collection('referrals').add(patientData);

      // STEP 3: Refresh local caches so UI reflects the new patient right away
      await Future.wait([
        _loadUnassignedPatients(),
        _loadAllPatients(),
        _loadDashboardStats(),
      ]);

      print(
          '✅ Patient referral added: $patientName (images: ${prescriptionImageUrls
              .length})');
      return true;
    } catch (e) {
      _errorMessage = 'Failed to add patient referral: $e';
      print('❌ Error adding patient referral: $e');
      return false;
    } finally {
      _setLoading(false);
      // Always notify listeners so UI can remove any loading indicators
      notifyListeners();
    }
  }

  // DOCTOR FUNCTIONS
  Future<List<AdminUser>> getDoctors() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'doctor')
          .where('status', isEqualTo: 'approved')
          .get();

      return snapshot.docs
          .map((doc) => AdminUser.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('❌ Error getting doctors: $e');
      return [];
    }
  }

  // THERAPIST PANEL FUNCTIONS
  Future<List<AdminPatient>> getTherapistPatients(String therapistId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('referrals')
          .where('therapistId', isEqualTo: therapistId)
          .orderBy('updatedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => AdminPatient.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('❌ Error getting therapist patients: $e');
      return [];
    }
  }

  Future<bool> addVisitLog({
    required String patientId,
    required String therapistId,
    required DateTime visitDate,
    required String notes,
    required String vasScore,
    required String progress,
    required bool followUpRequired,
    List<String>? photos,
  }) async {
    try {
      final visitData = {
        'visitDate': Timestamp.fromDate(visitDate),
        'therapistId': therapistId,
        'notes': notes,
        'vasScore': vasScore,
        'progress': progress,
        'followUpRequired': followUpRequired,
        'photos': photos ?? [],
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Add to visit history
      await _firestore.collection('referrals').doc(patientId).update({
        'visitHistory': FieldValue.arrayUnion([visitData]),
        'lastVisitDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'currentStatus': followUpRequired
            ? 'Follow-up Required'
            : 'In Progress',
      });

      // Create visit record
      await _firestore.collection('visits').add({
        'patientId': patientId,
        'therapistId': therapistId,
        'visitDate': Timestamp.fromDate(visitDate),
        'notes': notes,
        'vasScore': vasScore,
        'progress': progress,
        'followUpRequired': followUpRequired,
        'photos': photos ?? [],
        'status': 'completed',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _loadReportData();
      await _loadDashboardStats();

      print('✅ Visit log added for patient: $patientId');
      return true;
    } catch (e) {
      _errorMessage = 'Failed to add visit log: $e';
      print('❌ Error adding visit log: $e');
      notifyListeners();
      return false;
    }
  }

  // AUTOMATIC UPDATES & PROGRESS TRACKING
  Future<bool> updatePatientStatus({
    required String patientId,
    required String status, // 'Visited', 'Ongoing', 'Completed'
    String? notes,
  }) async {
    try {
      await _firestore.collection('referrals').doc(patientId).update({
        'currentStatus': status,
        'updatedAt': FieldValue.serverTimestamp(),
        'statusNotes': notes ?? '',
      });

      // Notify referring doctor
      await _sendStatusUpdateNotification(patientId, status);

      await _loadReportData();
      await _loadDashboardStats();

      print('✅ Patient status updated: $patientId -> $status');
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update patient status: $e';
      print('❌ Error updating patient status: $e');
      notifyListeners();
      return false;
    }
  }

  Future<void> _sendStatusUpdateNotification(String patientId,
      String status) async {
    try {
      // Get patient details
      DocumentSnapshot patientDoc = await _firestore
          .collection('referrals')
          .doc(patientId)
          .get();

      if (patientDoc.exists) {
        final patientData = patientDoc.data() as Map<String, dynamic>;

        // Create notification for referring doctor
        await _firestore.collection('notifications').add({
          'doctorId': patientData['doctorId'],
          'patientId': patientId,
          'patientName': patientData['patientName'],
          'status': status,
          'message': 'Patient ${patientData['patientName']} status updated to: $status',
          'type': 'status_update',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('❌ Error sending notification: $e');
    }
  }

  // REPORTS FUNCTIONS
  Future<void> _loadReportData() async {
    try {
      final now = DateTime.now();
      final thisWeekStart = now.subtract(Duration(days: now.weekday - 1));
      final thisMonthStart = DateTime(now.year, now.month, 1);

      // Referrals by Doctor Report
      final referralsByDoctor = await _getReferralsByDoctor();

      // Visits by Therapist Report
      final visitsByTherapist = await _getVisitsByTherapist();

      // Pending Follow-ups
      final pendingFollowups = await _getPendingFollowups();

      // Revenue calculations
      final revenueData = await _calculateRevenue();

      // Visit statistics
      final visitStats = await _getVisitStatistics();

      _reportData = {
        'referralsByDoctor': referralsByDoctor,
        'visitsByTherapist': visitsByTherapist,
        'pendingFollowups': pendingFollowups,
        'revenueData': revenueData,
        'visitStats': visitStats,
        'totalReferrals': referralsByDoctor.fold(
            0, (sum, item) => sum + (item['totalReferrals'] as int)),
        'completedVisits': visitStats['completedVisits'] ?? 0,
        'pendingFollowupsCount': pendingFollowups.length,
        'estimatedRevenue': revenueData['thisMonth'] ?? 0,
      };

      notifyListeners();
    } catch (e) {
      print('❌ Error loading report data: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _getReferralsByDoctor() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('referrals').get();

      Map<String, Map<String, dynamic>> doctorStats = {};

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final doctorName = data['doctorName'] ?? 'Unknown Doctor';
        final status = data['currentStatus'] ?? 'Pending';

        if (!doctorStats.containsKey(doctorName)) {
          doctorStats[doctorName] = {
            'doctorName': doctorName,
            'totalReferrals': 0,
            'completed': 0,
            'pending': 0,
            'ongoing': 0,
          };
        }

        doctorStats[doctorName]!['totalReferrals']++;

        if (status.toLowerCase().contains('completed')) {
          doctorStats[doctorName]!['completed']++;
        } else if (status.toLowerCase().contains('ongoing') ||
            status.toLowerCase().contains('progress')) {
          doctorStats[doctorName]!['ongoing']++;
        } else {
          doctorStats[doctorName]!['pending']++;
        }
      }

      return doctorStats.values.toList();
    } catch (e) {
      print('❌ Error getting referrals by doctor: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getVisitsByTherapist() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('visits').get();

      Map<String, Map<String, dynamic>> therapistStats = {};
      final now = DateTime.now();
      final thisWeekStart = now.subtract(Duration(days: now.weekday - 1));

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final therapistId = data['therapistId'] ?? '';
        final visitDate = _toDate(data['visitDate']);

        if (therapistId.isEmpty) continue;

        // Get therapist name
        final therapistName = await _getTherapistName(therapistId);

        if (!therapistStats.containsKey(therapistId)) {
          therapistStats[therapistId] = {
            'therapistName': therapistName,
            'totalVisits': 0,
            'thisWeekVisits': 0,
            'completionRate': 95, // Mock data for now
          };
        }

        therapistStats[therapistId]!['totalVisits']++;

        if (visitDate != null && visitDate.isAfter(thisWeekStart)) {
          therapistStats[therapistId]!['thisWeekVisits']++;
        }
      }

      return therapistStats.values.toList();
    } catch (e) {
      print('❌ Error getting visits by therapist: $e');
      return [];
    }
  }

  Future<String> _getTherapistName(String therapistId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(
          therapistId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['name'] ?? 'Unknown Therapist';
      }
      return 'Unknown Therapist';
    } catch (e) {
      return 'Unknown Therapist';
    }
  }

  Future<List<Map<String, dynamic>>> _getPendingFollowups() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('referrals')
          .where('currentStatus', isEqualTo: 'Follow-up Required')
          .get();

      List<Map<String, dynamic>> followups = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final visitHistory = data['visitHistory'] as List<dynamic>? ?? [];

        if (visitHistory.isNotEmpty) {
          final lastVisit = visitHistory.last as Map<String, dynamic>;
          final lastVisitDate = _toDate(lastVisit['visitDate']);
          final dueDate = lastVisitDate?.add(
              Duration(days: 7)); // 1 week follow-up

          followups.add({
            'patientName': data['patientName'] ?? 'Unknown Patient',
            'therapistName': data['therapistName'] ?? 'Unknown Therapist',
            'lastVisitDate': lastVisitDate?.toString().split(' ')[0] ??
                'Unknown',
            'dueDate': dueDate?.toString().split(' ')[0] ?? 'Unknown',
            'patientId': doc.id,
          });
        }
      }

      return followups;
    } catch (e) {
      print('❌ Error getting pending followups: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> _calculateRevenue() async {
    try {
      final now = DateTime.now();
      final thisWeekStart = now.subtract(Duration(days: now.weekday - 1));
      final thisMonthStart = DateTime(now.year, now.month, 1);

      QuerySnapshot visitsSnapshot = await _firestore
          .collection('visits')
          .get();

      int thisWeekRevenue = 0;
      int thisMonthRevenue = 0;
      int thisWeekVisits = 0;
      int thisMonthVisits = 0;

      const int costPerVisit = 1800; // ₹1800 per visit

      for (var doc in visitsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final visitDate = _toDate(data['visitDate']);

        if (visitDate != null) {
          if (visitDate.isAfter(thisWeekStart)) {
            thisWeekRevenue += costPerVisit;
            thisWeekVisits++;
          }

          if (visitDate.isAfter(thisMonthStart)) {
            thisMonthRevenue += costPerVisit;
            thisMonthVisits++;
          }
        }
      }

      return {
        'thisWeek': thisWeekRevenue,
        'thisMonth': thisMonthRevenue,
        'thisWeekVisits': thisWeekVisits,
        'thisMonthVisits': thisMonthVisits,
        'costPerVisit': costPerVisit,
      };
    } catch (e) {
      print('❌ Error calculating revenue: $e');
      return {
        'thisWeek': 0,
        'thisMonth': 0,
        'thisWeekVisits': 0,
        'thisMonthVisits': 0,
        'costPerVisit': 1800,
      };
    }
  }

  Future<Map<String, dynamic>> _getVisitStatistics() async {
    try {
      QuerySnapshot visitsSnapshot = await _firestore
          .collection('visits')
          .get();
      QuerySnapshot referralsSnapshot = await _firestore
          .collection('referrals')
          .get();

      return {
        'completedVisits': visitsSnapshot.docs.length,
        'totalReferrals': referralsSnapshot.docs.length,
        'averageVisitsPerPatient': referralsSnapshot.docs.isNotEmpty
            ? (visitsSnapshot.docs.length / referralsSnapshot.docs.length)
            .round()
            : 0,
      };
    } catch (e) {
      print('❌ Error getting visit statistics: $e');
      return {
        'completedVisits': 0,
        'totalReferrals': 0,
        'averageVisitsPerPatient': 0,
      };
    }
  }

  // Helper to convert Firestore date (Timestamp/String) to DateTime
  DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      try {
        // Try ISO8601
        return DateTime.parse(value);
      } catch (_) {
        // Try common other formats (e.g., dd-MM-yyyy)
        try {
          return DateFormat('yyyy-MM-dd').parse(value);
        } catch (_) {
          return null;
        }
      }
    }
    return null;
  }

  /// Uploads an image to Firebase Storage with retries and returns the download URL.
  /// Retries are attempted on any exception or timeout.
  Future<String> _uploadImageWithRetry(Uint8List bytes, int index,
      {int retries = 2}) async {
    int attempt = 0;
    while (true) {
      try {
        final ref = _storage
            .ref()
            .child('prescriptions/${DateTime
            .now()
            .millisecondsSinceEpoch}_$index.jpg');

        final metadata = SettableMetadata(contentType: 'image/jpeg');

        // 2-minute timeout – larger than the previous 60 s to accommodate slow links
        await ref.putData(bytes, metadata).timeout(const Duration(minutes: 2));
        return await ref.getDownloadURL();
      } on TimeoutException catch (_) {
        attempt++;
        if (attempt > retries) rethrow;
      } catch (e) {
        attempt++;
        if (attempt > retries) rethrow;
      }
    }
  }

  // EXCEL EXPORT FUNCTION
  Future<Map<String, dynamic>> getExportData({
    required String reportType,
    required String period,
  }) async {
    try {
      Map<String, dynamic> exportData = {};

      switch (reportType) {
        case 'Referrals by Doctor':
          exportData = {
            'title': 'Referrals by Doctor Report',
            'period': period,
            'data': _reportData['referralsByDoctor'] ?? [],
            'headers': [
              'Doctor Name',
              'Total Referrals',
              'Completed',
              'Pending',
              'Ongoing'
            ],
          };
          break;
        case 'Visits by Therapist':
          exportData = {
            'title': 'Visits by Therapist Report',
            'period': period,
            'data': _reportData['visitsByTherapist'] ?? [],
            'headers': [
              'Therapist Name',
              'Total Visits',
              'This Week',
              'Completion Rate'
            ],
          };
          break;
        case 'Pending Follow-ups':
          exportData = {
            'title': 'Pending Follow-ups Report',
            'period': period,
            'data': _reportData['pendingFollowups'] ?? [],
            'headers': ['Patient Name', 'Therapist', 'Last Visit', 'Due Date'],
          };
          break;
        case 'Revenue Report':
          exportData = {
            'title': 'Revenue Report',
            'period': period,
            'data': _reportData['revenueData'] ?? {},
            'summary': {
              'thisWeekRevenue': _reportData['revenueData']?['thisWeek'] ?? 0,
              'thisMonthRevenue': _reportData['revenueData']?['thisMonth'] ?? 0,
              'totalVisits': _reportData['visitStats']?['completedVisits'] ?? 0,
            },
          };
          break;
        default:
          exportData = {
            'title': 'Complete Admin Report',
            'period': period,
            'referrals': _reportData['referralsByDoctor'] ?? [],
            'visits': _reportData['visitsByTherapist'] ?? [],
            'followups': _reportData['pendingFollowups'] ?? [],
            'revenue': _reportData['revenueData'] ?? {},
          };
      }

      return exportData;
    } catch (e) {
      print('❌ Error preparing export data: $e');
      return {};
    }
  }

  // Enhanced dashboard stats
  Future<void> _loadDashboardStats() async {
    try {
      // Get user counts by status
      final pendingUsersCount = await _firestore
          .collection('users')
          .where('status', isEqualTo: 'pending')
          .get();

      final approvedUsersCount = await _firestore
          .collection('users')
          .where('status', isEqualTo: 'approved')
          .get();

      final doctorsCount = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'doctor')
          .where('status', isEqualTo: 'approved')
          .get();

      final therapistsCount = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'therapist')
          .where('status', isEqualTo: 'approved')
          .get();

      // Get patient counts
      final totalPatientsCount = await _firestore
          .collection('referrals')
          .get();

      final unassignedPatientsCount = await _firestore
          .collection('referrals')
          .where('therapistId', isNull: true)
          .get();

      // Get visit counts
      final totalVisitsCount = await _firestore
          .collection('visits')
          .get();

      // Get pending followups
      final pendingFollowupsCount = await _firestore
          .collection('referrals')
          .where('currentStatus', isEqualTo: 'Follow-up Required')
          .get();

      _dashboardStats = {
        'pendingUsers': pendingUsersCount.docs.length,
        'approvedUsers': approvedUsersCount.docs.length,
        'doctors': doctorsCount.docs.length,
        'therapists': therapistsCount.docs.length,
        'totalPatients': totalPatientsCount.docs.length,
        'unassignedPatients': unassignedPatientsCount.docs.length,
        'totalVisits': totalVisitsCount.docs.length,
        'pendingFollowups': pendingFollowupsCount.docs.length,
        'totalReferrals': _reportData['totalReferrals'] ??
            totalPatientsCount.docs.length,
        'completedVisits': _reportData['completedVisits'] ??
            totalVisitsCount.docs.length,
        'estimatedRevenue': _reportData['estimatedRevenue'] ?? 0,
      };

      notifyListeners();
    } catch (e) {
      print('❌ Error loading dashboard stats: $e');
    }
  }

  Future<void> _loadAllPatients() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('referrals')
          .orderBy('createdAt', descending: true)
          .get();

      _allPatients = snapshot.docs
          .map((doc) => AdminPatient.fromFirestore(doc))
          .toList();

      notifyListeners();
    } catch (e) {
      print('❌ Error loading all patients: $e');
    }
  }

  // Existing functions remain the same...
  Future<void> _loadPendingUsers() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      _pendingUsers = snapshot.docs
          .map((doc) => AdminUser.fromFirestore(doc))
          .toList();

      notifyListeners();
    } catch (e) {
      print('❌ Error loading pending users: $e');
    }
  }

  Future<void> _loadAllUsers() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .orderBy('createdAt', descending: true)
          .get();

      _allUsers = snapshot.docs
          .map((doc) => AdminUser.fromFirestore(doc))
          .toList();

      notifyListeners();
    } catch (e) {
      print('❌ Error loading all users: $e');
    }
  }

  Future<void> _loadUnassignedPatients() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('referrals')
          .where('therapistId', isNull: true)
          .orderBy('createdAt', descending: true)
          .get();

      _unassignedPatients = snapshot.docs
          .map((doc) => AdminPatient.fromFirestore(doc))
          .toList();

      notifyListeners();
    } catch (e) {
      print('❌ Error loading unassigned patients: $e');
    }
  }

  // User approval operations
  Future<bool> approveUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
      });

      await _loadPendingUsers();
      await _loadDashboardStats();

      print('✅ User approved: $userId');
      return true;
    } catch (e) {
      _errorMessage = 'Failed to approve user: $e';
      print('❌ Error approving user: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      await _loadPendingUsers();
      await _loadDashboardStats();

      print('✅ User rejected: $userId');
      return true;
    } catch (e) {
      _errorMessage = 'Failed to reject user: $e';
      print('❌ Error rejecting user: $e');
      notifyListeners();
      return false;
    }
  }

  // Patient assignment operations
  Future<bool> assignPatientToTherapist({
    required String patientId,
    required String therapistId,
    required String therapistName,
  }) async {
    try {
      await _firestore.collection('referrals').doc(patientId).update({
        'therapistId': therapistId,
        'therapistName': therapistName,
        'status': 'assigned',
        'currentStatus': 'Assigned to Therapist',
        'assignedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create notification for therapist
      await _firestore.collection('notifications').add({
        'therapistId': therapistId,
        'patientId': patientId,
        'type': 'new_assignment',
        'message': 'New patient has been assigned to you',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _loadUnassignedPatients();
      await _loadDashboardStats();

      print('✅ Patient assigned: $patientId to $therapistName');
      return true;
    } catch (e) {
      _errorMessage = 'Failed to assign patient: $e';
      print('❌ Error assigning patient: $e');
      notifyListeners();
      return false;
    }
  }

  // Get therapists for patient assignment
  Future<List<AdminUser>> getAvailableTherapists() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'therapist')
          .where('status', isEqualTo: 'approved')
          .get();

      return snapshot.docs
          .map((doc) => AdminUser.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('❌ Error getting therapists: $e');
      return [];
    }
  }

  // Refresh all data
  Future<void> refreshData() async {
    await _loadInitialData();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Fetches all patient report data for the ReportsTab and stores it in _reportData['patientReport'].
  Future<void> fetchPatientReport() async {
    _setLoading(true);
    try {
      QuerySnapshot snapshot = await _firestore.collection('referrals').get();
      _reportData['patientReport'] = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'name': data['patientName'] ?? '',
          'therapist': data['therapistName'] ?? '',
          'doctor': data['doctorName'] ?? '',
          'lastVisit': data['lastVisitDate'] != null
              ? (data['lastVisitDate'] is Timestamp
              ? (data['lastVisitDate'] as Timestamp).toDate().toString().split(
              ' ')[0]
              : data['lastVisitDate'].toString().split(' ')[0])
              : '',
        };
      }).toList();
    } catch (e) {
      _reportData['patientReport'] = [];
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }
}