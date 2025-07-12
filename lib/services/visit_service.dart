import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/admin_patient.dart';
import '../models/visit_log.dart';
import '../models/visit_model.dart';
import 'dart:async';

class VisitService {
  final _db = FirebaseFirestore.instance;
  
  // Cache for therapist names to avoid excessive database calls
  final Map<String, String> _therapistNameCache = {};
  
  // Cache for patient data
  final Map<String, AdminPatient> _patientCache = {};

  // Fetch all patients
  Future<List<AdminPatient>> getAllPatients() async {
    final snap = await _db.collection('patients').get();
    final patients = snap.docs.map((doc) => AdminPatient.fromFirestore(doc)).toList();
    
    // Update cache
    for (final patient in patients) {
      _patientCache[patient.id] = patient;
    }
    
    return patients;
  }
  
  // Fetch patients by therapist ID
  Future<List<AdminPatient>> getPatientsByTherapist(String therapistId) async {
    final snap = await _db.collection('patients')
        .where('therapistId', isEqualTo: therapistId)
        .get();
    
    final patients = snap.docs.map((doc) => AdminPatient.fromFirestore(doc)).toList();
    
    // Update cache
    for (final patient in patients) {
      _patientCache[patient.id] = patient;
    }
    
    return patients;
  }
  
  // Get patient by ID (with caching)
  Future<AdminPatient?> getPatientById(String patientId) async {
    // Return from cache if available
    if (_patientCache.containsKey(patientId)) {
      return _patientCache[patientId];
    }
    
    try {
      final doc = await _db.collection('patients').doc(patientId).get();
      if (doc.exists) {
        final patient = AdminPatient.fromFirestore(doc);
        _patientCache[patientId] = patient;
        return patient;
      }
    } catch (e) {
      print('Error fetching patient: $e');
    }
    
    return null;
  }

  // Stream visit logs for a patient (basic version)
  Stream<List<VisitLog>> getVisitLogsForPatient(String patientId) {
    return _db
        .collection('visits')
        .where('patientId', isEqualTo: patientId)
        .orderBy('visitDate', descending: true)
        .snapshots()
        .map((q) =>
        q.docs.map((d) => VisitLog.fromMap(d.id, d.data())).toList());
  }
  
  // Get enhanced visit models for a patient
  Stream<List<VisitModel>> getTreatmentLogsForPatient(String patientId) {
    return _db
        .collection('visits')
        .where('patientId', isEqualTo: patientId)
        .orderBy('visitDate', descending: true)
        .snapshots()
        .map((q) =>
        q.docs.map((d) => VisitModel.fromMap(d.id, d.data())).toList());
  }
  
  // Get all treatment logs (for admin)
  Stream<List<VisitModel>> getAllTreatmentLogs() {
    return _db
        .collection('visits')
        .orderBy('visitDate', descending: true)
        .snapshots()
        .map((q) =>
        q.docs.map((d) => VisitModel.fromMap(d.id, d.data())).toList());
  }
  
  // Get treatment logs by therapist
  Stream<List<VisitModel>> getTreatmentLogsByTherapist(String therapistId) {
    return _db
        .collection('visits')
        .where('therapistId', isEqualTo: therapistId)
        .orderBy('visitDate', descending: true)
        .snapshots()
        .map((q) =>
        q.docs.map((d) => VisitModel.fromMap(d.id, d.data())).toList());
  }
  
  // Get a single treatment log
  Future<VisitModel?> getTreatmentLog(String id) async {
    try {
      final doc = await _db.collection('visits').doc(id).get();
      if (doc.exists) {
        return VisitModel.fromMap(doc.id, doc.data()!);
      }
    } catch (e) {
      print('Error fetching treatment log: $e');
    }
    return null;
  }
  
  // Get visit count for a patient as a stream
  Stream<int> getVisitCountForPatient(String patientId) {
    return _db
        .collection('visits')
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Add new log (basic version)
  Future<void> addVisitLog(String therapistId, String patientId, DateTime date, String notes) async {
    // Get therapist name
    final therapistName = await getTherapistNameAsync(therapistId) ?? therapistId;
    
    await _db.collection('visits').add({
      'therapistId': therapistId,
      'therapistName': therapistName,
      'patientId': patientId,
      'visitDate': date,
      'notes': notes,
      'status': 'completed',
      'followUpRequired': false,
      'createdAt': DateTime.now(),
    });
    
    // Update patient status to visited
    await _db.collection('patients').doc(patientId).update({
      'status': 'visited',
      'lastVisitDate': date,
    });
  }
  
  // Add comprehensive treatment log
  Future<String> addTreatmentLog(VisitModel visit) async {
    // Ensure we have therapist name
    String therapistName = visit.therapistName;
    if (therapistName.isEmpty) {
      therapistName = await getTherapistNameAsync(visit.therapistId) ?? visit.therapistId;
    }
    
    // Create data map with therapist name
    final data = visit.toMap();
    data['therapistName'] = therapistName;
    
    // Add to Firestore
    final docRef = await _db.collection('visits').add(data);
    
    // Update patient status
    await _db.collection('patients').doc(visit.patientId).update({
      'status': visit.followUpRequired ? 'ongoing' : 'visited',
      'lastVisitDate': visit.visitDate,
      'followUpRequired': visit.followUpRequired,
    });
    
    return docRef.id;
  }
  
  // Update treatment log
  Future<void> updateTreatmentLog(String id, VisitModel visit) async {
    await _db.collection('visits').doc(id).update({
      ...visit.toMap(),
      'updatedAt': DateTime.now(),
    });
    
    // Update patient status if needed
    await _db.collection('patients').doc(visit.patientId).update({
      'followUpRequired': visit.followUpRequired,
    });
  }
  
  // Delete treatment log
  Future<void> deleteTreatmentLog(String id, String patientId) async {
    await _db.collection('visits').doc(id).delete();
    
    // Check if this was the last visit for the patient
    final visits = await _db.collection('visits')
        .where('patientId', isEqualTo: patientId)
        .orderBy('visitDate', descending: true)
        .limit(1)
        .get();
    
    if (visits.docs.isEmpty) {
      // No more visits, update patient status
      await _db.collection('patients').doc(patientId).update({
        'status': 'assigned',
      });
    }
  }
  
  // Get therapist name from ID
  Future<String?> getTherapistNameAsync(String therapistId) async {
    // Return from cache if available
    if (_therapistNameCache.containsKey(therapistId)) {
      return _therapistNameCache[therapistId];
    }
    
    try {
      final doc = await _db.collection('therapists').doc(therapistId).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data.containsKey('name')) {
          final name = data['name'] as String;
          // Cache the result
          _therapistNameCache[therapistId] = name;
          return name;
        }
      }
      return null;
    } catch (e) {
      print('Error fetching therapist name: $e');
      return null;
    }
  }
  
  // Synchronous method to get therapist name (returns cached value or null)
  String? getTherapistName(String therapistId) {
    return _therapistNameCache[therapistId];
  }
  
  // Stream for therapist name
  Stream<String> getTherapistNameStream(String therapistId) {
    // Create a controller for the stream
    final controller = StreamController<String>();
    
    // If we have a cached name, emit it immediately
    if (_therapistNameCache.containsKey(therapistId)) {
      controller.add(_therapistNameCache[therapistId]!);
    } else {
      // Otherwise fetch it
      getTherapistNameAsync(therapistId).then((name) {
        if (name != null) {
          controller.add(name);
        } else {
          // If no name found, use the ID
          controller.add(therapistId);
        }
      }).catchError((error) {
        // On error, use the ID
        controller.add(therapistId);
      });
    }
    
    return controller.stream;
  }

  /// Ensures a therapist exists in Firestore under the therapists collection.
  /// Call this after a therapist logs in. If the therapist doc is missing, it will be created.
  static Future<void> ensureTherapistInFirestore({
    required String userId,
    required String name,
    required String email,
    String? specialization,
    String? qualification,
    String? phone,
  }) async {
    final doc = FirebaseFirestore.instance.collection('therapists').doc(userId);
    final docSnapshot = await doc.get();
    if (!docSnapshot.exists) {
      // Create the therapist profile if it doesn't exist
      await doc.set({
        'name': name,
        'email': email,
        'specialization': specialization ?? '',
        'qualification': qualification ?? '',
        'phone': phone ?? '',
        // Add other fields as required
      });
    }
  }
}
