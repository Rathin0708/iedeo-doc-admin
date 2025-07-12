import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iedeo_doc_admin/screens/therapist_referrals_screen.dart';
import '../models/therapist_model.dart';
import '../services/visit_service.dart';
import 'therapist_patients_screen.dart';
import 'package:intl/intl.dart'; // For date formatting

class VisitsScreen extends StatelessWidget {
  const VisitsScreen({Key? key}) : super(key: key);

  // Build therapist card displaying all details (from Firestore user doc)
  Widget _buildTherapistCardFromUser(BuildContext context,
      Map<String, dynamic> data, String userId) {
    // Null-safe field fetching with fallbacks
    final displayName = (data['name'] != null && data['name']
        .toString()
        .isNotEmpty) ? data['name'] : 'N/A';
    final displayEmail = (data['email'] != null && data['email']
        .toString()
        .isNotEmpty) ? data['email'] : 'N/A';
    final displaySpecialization = (data['specialization'] != null &&
        data['specialization']
            .toString()
            .isNotEmpty) ? data['specialization'] : 'N/A';
    final displayQualification = (data['qualification'] != null &&
        data['qualification']
            .toString()
            .isNotEmpty) ? data['qualification'] : 'N/A';
    final displayPhone = (data['phone'] != null && data['phone']
        .toString()
        .isNotEmpty) ? data['phone'] : 'N/A';

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  TherapistReferralsScreen(
                    therapistData: data,
                    therapistId: userId,
                  ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      displayName[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          displaySpecialization,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          displayQualification,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          displayEmail,
                          style: TextStyle(
                              color: Colors.grey.shade800, fontSize: 14),
                        ),
                        Text(
                          displayPhone,
                          style: TextStyle(
                              color: Colors.grey.shade800, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // No navigation or button for now, as model doesn't match
              // Align(
              //   alignment: Alignment.centerRight,
              //   child: ElevatedButton.icon(
              //     onPressed: () => _showTherapistPatients(context, data),
              //     icon: const Icon(Icons.people),
              //     label: const Text('View Patients'),
              //     style: ElevatedButton.styleFrom(
              //       backgroundColor: Colors.blue,
              //       foregroundColor: Colors.white,
              //     ),
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }

  // Build a card for each visit log document from Firestore
  Widget _buildVisitLogCard(BuildContext context, DocumentSnapshot visitLog) {
    final data = visitLog.data() as Map<String, dynamic>;
    final DateTime? time = data['timestamp'] != null
        ? (data['timestamp'] is Timestamp ? (data['timestamp'] as Timestamp)
        .toDate() : null)
        : null;
    final formattedTime = time != null ? DateFormat('yyyy-MM-dd – kk:mm')
        .format(time) : 'No date';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      child: ListTile(
        leading: const Icon(Icons.history, color: Colors.blueAccent),
        title: Text(data['description'] ?? 'No description'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('By: 	${data['performedBy'] ?? 'Unknown'}'),
            Text('Type: ${data['type'] ?? ''}'),
            Text('User ID: ${data['userId'] ?? ''}'),
            Text('At: $formattedTime'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Two tabs: Therapists & Visit Logs
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Visits'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Therapists', icon: Icon(Icons.medical_services)),
              Tab(text: 'Visit Logs', icon: Icon(Icons.history)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ----- 1st Tab: Therapist Details List from users collection -----
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('role', isEqualTo: 'therapist')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    print('No therapist users found in Firestore.');
                    return const Center(child: Text('No therapists found'));
                  }
                  final users = snapshot.data!.docs;
                  users.forEach((doc) {
                    print('Loaded user: id: '
                        '${doc.id}, data: ${doc.data()}');
                  });
                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final doc = users[index];
                      final data = doc.data() as Map<String, dynamic>;
                      return _buildTherapistCardFromUser(context, data, doc.id);
                    },
                  );
                },
              ),
            ),
            // ----- 2nd Tab: Visit Logs List -----
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('visit_logs')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No visit logs found'));
                  }
                  return ListView(
                    children: snapshot.data!.docs
                        .map((doc) => _buildVisitLogCard(context, doc))
                        .toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
