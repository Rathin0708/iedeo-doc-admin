import 'package:cloud_firestore/cloud_firestore.dart';

class TherapistModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? specialization;
  final String? qualification;
  final String? profileImageUrl;
  final String? bio;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  TherapistModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.specialization,
    this.qualification,
    this.profileImageUrl,
    this.bio,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
  });

  factory TherapistModel.fromMap(String id, Map<String, dynamic> data) {
    return TherapistModel(
      id: id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'],
      specialization: data['specialization'],
      qualification: data['qualification'],
      profileImageUrl: data['profileImageUrl'],
      bio: data['bio'],
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory TherapistModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TherapistModel.fromMap(doc.id, data);
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'specialization': specialization,
      'qualification': qualification,
      'profileImageUrl': profileImageUrl,
      'bio': bio,
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt ?? DateTime.now(),
    };
  }
}
