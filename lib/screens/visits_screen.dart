import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iedeo_doc_admin/screens/therapist_assigned_patients_screen.dart';
import 'package:iedeo_doc_admin/screens/therapist_referrals_screen.dart';
import '../models/therapist_model.dart';
import '../services/visit_service.dart';
import 'therapist_patients_screen.dart';

class VisitsScreen extends StatefulWidget {
  const VisitsScreen({Key? key}) : super(key: key);

  @override
  State<VisitsScreen> createState() => _VisitsScreenState();
}

class _VisitsScreenState extends State<VisitsScreen> {
  String _searchQuery = '';
  String _specialization = 'All';
  String _qualification = 'All';

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
                  TherapistAssignedPatientsScreen(
                    therapistId: userId,
                    therapistName: displayName,
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
            Text('At: ${data['timestamp'] ?? 'No date'}'),
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
        // AppBar removed as requested
        body: Column(
          children: [
            Material(
              color: Color(0xFF4CAF7E), // Match your brand
              child: const TabBar(
                labelColor: Colors.white,
                indicatorColor: Colors.white,
                tabs: [
                  Tab(text: 'Therapists', icon: Icon(Icons.medical_services)),
                  Tab(text: 'Visit Logs', icon: Icon(Icons.history)),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // ----- 1st Tab: Therapist Details List from users collection -----
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // --- Search Bar Filter ---
                        TextField(
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: 'Search therapists by name, email, phone...',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () =>
                                  setState(() => _searchQuery = ''),
                            )
                                : null,
                          ),
                          onChanged: (text) =>
                              setState(() => _searchQuery = text.trim()),
                        ),
                        const SizedBox(height: 10),
                        // --- Advanced Filters: Specialization + Qualification ---
                        FutureBuilder(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .where('role', isEqualTo: 'therapist')
                              .get(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                            if (!snapshot.hasData) {
                              return const SizedBox.shrink();
                            }
                            final users = (snapshot.data as QuerySnapshot).docs;
                            final specializations = [
                              'All',
                              ...{
                                for (var doc in users)
                                  ((doc.data() as Map<String,
                                      dynamic>)['specialization'] ?? '')
                                      .toString()
                                      .trim()
                              }.where((v) => v.isNotEmpty)
                            ];
                            final qualifications = [
                              'All',
                              ...{
                                for (var doc in users)
                                  ((doc.data() as Map<String,
                                      dynamic>)['qualification'] ?? '')
                                      .toString()
                                      .trim()
                              }.where((v) => v.isNotEmpty)
                            ];
                            return Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _specialization,
                                    items: specializations
                                        .map((s) =>
                                        DropdownMenuItem(
                                            value: s, child: Text(s)))
                                        .toList(),
                                    onChanged: (val) =>
                                        setState(() => _specialization = val!),
                                    decoration: InputDecoration(
                                      labelText: 'Specialization',
                                      border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                              10)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _qualification,
                                    items: qualifications
                                        .map((q) =>
                                        DropdownMenuItem(
                                            value: q, child: Text(q)))
                                        .toList(),
                                    onChanged: (val) =>
                                        setState(() => _qualification = val!),
                                    decoration: InputDecoration(
                                      labelText: 'Qualification',
                                      border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                              10)),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.clear_all),
                                  tooltip: 'Clear filters',
                                  onPressed: () =>
                                      setState(() {
                                        _specialization = 'All';
                                        _qualification = 'All';
                                        _searchQuery = '';
                                      }),
                                )
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 15),
                        // --- Therapist List (Filtered) ---
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .where('role', isEqualTo: 'therapist')
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }
                              if (snapshot.hasError) {
                                return Center(child: Text(
                                    'Error: ${snapshot.error}'));
                              }
                              if (!snapshot.hasData ||
                                  snapshot.data!.docs.isEmpty) {
                                return const Center(child: Text(
                                    'No therapists found'));
                              }
                              final users = snapshot.data!.docs;
                              final filteredUsers = users.where((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final name = data['name']
                                    ?.toString()
                                    .toLowerCase() ??
                                    '';
                                final email = data['email']
                                    ?.toString()
                                    .toLowerCase() ?? '';
                                final phone = data['phone']
                                    ?.toString()
                                    .toLowerCase() ?? '';
                                final specialization = (data['specialization'] ??
                                    '')
                                    .toString();
                                final qualification = (data['qualification'] ??
                                    '')
                                    .toString();
                                final q = _searchQuery.toLowerCase();
                                final matchesSearch = _searchQuery.isEmpty ||
                                    name.contains(q) || email.contains(q) ||
                                    phone.contains(q);
                                final matchesSpec = _specialization == 'All' ||
                                    specialization == _specialization;
                                final matchesQual = _qualification == 'All' ||
                                    qualification == _qualification;
                                return matchesSearch && matchesSpec &&
                                    matchesQual;
                              }).toList();
                              if (filteredUsers.isEmpty) {
                                return const Center(child: Text(
                                    'No therapists match these filters.'));
                              }
                              return ListView.builder(
                                itemCount: filteredUsers.length,
                                itemBuilder: (context, index) {
                                  final doc = filteredUsers[index];
                                  final data = doc.data() as Map<String,
                                      dynamic>;
                                  return _buildTherapistCardFromUser(
                                      context, data, doc.id);
                                },
                              );
                            },
                          ),
                        ),
                      ],
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
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(
                              child: Text('Error: ${snapshot.error}'));
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(
                              child: Text('No visit logs found'));
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
          ],
        ),
      ),
    );
  }
}
