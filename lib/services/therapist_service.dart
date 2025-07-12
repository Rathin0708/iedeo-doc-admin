import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/therapist_model.dart';

class TherapistService {
  final _db = FirebaseFirestore.instance;
  
  // Cache for therapist data
  final Map<String, TherapistModel> _therapistCache = {};

  // Get all therapists
  Future<List<TherapistModel>> getAllTherapists() async {
    try {
      final snap = await _db.collection('therapists').get();
      final therapists = snap.docs.map((doc) => TherapistModel.fromFirestore(doc)).toList();
      
      // Update cache
      for (final therapist in therapists) {
        _therapistCache[therapist.id] = therapist;
      }
      
      return therapists;
    } catch (e) {
      print('Error fetching therapists: $e');
      return [];
    }
  }
  
  // Get therapist by ID (with caching)
  Future<TherapistModel?> getTherapistById(String therapistId) async {
    // Return from cache if available
    if (_therapistCache.containsKey(therapistId)) {
      return _therapistCache[therapistId];
    }
    
    try {
      final doc = await _db.collection('therapists').doc(therapistId).get();
      if (doc.exists) {
        final therapist = TherapistModel.fromFirestore(doc);
        _therapistCache[therapistId] = therapist;
        return therapist;
      }
    } catch (e) {
      print('Error fetching therapist: $e');
    }
    
    return null;
  }

  // Stream for a specific therapist
  Stream<TherapistModel?> getTherapistStream(String therapistId) {
    return _db
        .collection('therapists')
        .doc(therapistId)
        .snapshots()
        .map((doc) {
          if (doc.exists) {
            final therapist = TherapistModel.fromFirestore(doc);
            _therapistCache[therapistId] = therapist;
            return therapist;
          }
          return null;
        });
  }

  // Get active therapists
  Future<List<TherapistModel>> getActiveTherapists() async {
    try {
      final snap = await _db
          .collection('therapists')
          .where('isActive', isEqualTo: true)
          .get();
      
      final therapists = snap.docs.map((doc) => TherapistModel.fromFirestore(doc)).toList();
      
      // Update cache
      for (final therapist in therapists) {
        _therapistCache[therapist.id] = therapist;
      }
      
      return therapists;
    } catch (e) {
      print('Error fetching active therapists: $e');
      return [];
    }
  }
}
