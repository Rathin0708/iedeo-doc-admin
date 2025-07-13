import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iedeo_doc_admin/screens/therapist_assigned_patients_screen.dart';
import 'package:intl/intl.dart';

class VisitsScreen extends StatefulWidget {
  const VisitsScreen({super.key});

  @override
  State<VisitsScreen> createState() => _VisitsScreenState();
}

class _VisitsScreenState extends State<VisitsScreen> {
  String _searchQuery = '';
  String _specialization = 'All';
  String _qualification = 'All';
  String _visitSearch = '';
  String _visitType = 'All';
  String _visitStatus = 'All';
  DateTime? _visitDateFrom;
  DateTime? _visitDateTo;

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
            ],
          ),
        ),
      ),
    );
  }

  // Build a card for each visit log document from Firestore

  // Handler for the resend button; here you can add your resend logic (e.g. notification, email, etc.)

  Widget _buildVisitCard(BuildContext context, DocumentSnapshot visitDoc) {
    final data = visitDoc.data() as Map<String, dynamic>;
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Patient: ${data['patientName'] ?? 'N/A'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Patient ID: ${data['patientId'] ?? ''}'),
            Text('Date: ${data['visitDate'] ?? ''}   Time: ${data['visitTime'] ?? ''}'),
            Text('Type: ${data['visitType'] ?? ''}'),
            Text('Status: ${data['status'] ?? ''}'),
            Text('VAS Score: ${data['vasScore'] ?? ''}'),
            Text('Treatment Notes: ${data['treatmentNotes'] ?? ''}'),
            Text('Progress Notes: ${data['progressNotes'] ?? ''}'),
            Text('Notes: ${data['notes'] ?? ''}'),
            Text('Amount: ₹${data['amount'] ?? ''}'),
            Text('Follow Up Required: ${(data['followUpRequired'] ?? false) ? 'Yes' : 'No'}'),
            Text('Created At: ${data['createdAt'] ?? ''}'),
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
                    child: Column(
                      children: [
                        // --- Visit Logs Filters ---
                        Row(
                          children: [
                            // Search TextField
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: 'Search (Patient, ID, Type)',
                                  prefixIcon: Icon(Icons.search),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  suffixIcon: _visitSearch.isNotEmpty
                                      ? IconButton(
                                    icon: Icon(Icons.clear),
                                    onPressed: () =>
                                        setState(() => _visitSearch = ''),
                                  )
                                      : null,
                                ),
                                onChanged: (text) =>
                                    setState(() => _visitSearch = text.trim()),
                              ),
                            ),
                            SizedBox(width: 8),
                            // Visit Type Dropdown
                            DropdownButton<String>(
                              value: _visitType,
                              items: [
                                'All',
                                'First Visit',
                                'Follow Up',
                                'Other',
                              ]
                                  .map((type) =>
                                  DropdownMenuItem(
                                      value: type, child: Text(type)))
                                  .toList(),
                              onChanged: (val) =>
                                  setState(() => _visitType = val!),
                              underline: SizedBox(),
                            ),
                            SizedBox(width: 8),
                            // Visit Status Dropdown
                            DropdownButton<String>(
                              value: _visitStatus,
                              items: [
                                'All',
                                'Completed',
                                'Pending',
                                'Cancelled',
                              ]
                                  .map((status) =>
                                  DropdownMenuItem(
                                      value: status, child: Text(status)))
                                  .toList(),
                              onChanged: (val) =>
                                  setState(() => _visitStatus = val!),
                              underline: SizedBox(),
                            ),
                          ],
                        ),
                        // --- Date Range Filters ---
                        Row(
                          children: [
                            TextButton.icon(
                              icon: Icon(Icons.calendar_today),
                              label: Text(_visitDateFrom == null
                                  ? 'From Date'
                                  : DateFormat('dd MMM yyyy').format(
                                  _visitDateFrom!)),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _visitDateFrom ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now().add(
                                      const Duration(days: 365)),
                                );
                                if (picked != null) setState(() =>
                                _visitDateFrom = picked);
                              },
                            ),
                            const SizedBox(width: 6),
                            TextButton.icon(
                              icon: Icon(Icons.calendar_today),
                              label: Text(_visitDateTo == null
                                  ? 'To Date'
                                  : DateFormat('dd MMM yyyy').format(
                                  _visitDateTo!)),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _visitDateTo ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now().add(
                                      const Duration(days: 365)),
                                );
                                if (picked != null) setState(() =>
                                _visitDateTo = picked);
                              },
                            ),
                            if (_visitDateFrom != null || _visitDateTo != null)
                              IconButton(
                                icon: Icon(Icons.clear),
                                tooltip: 'Clear date filters',
                                onPressed: () =>
                                    setState(() {
                                      _visitDateFrom = null;
                                      _visitDateTo = null;
                                    }),
                              ),
                          ],
                        ),
                        SizedBox(height: 12),
                        // --- Visits List (filtered) ---
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('visits')
                                .orderBy('visitDate', descending: true)
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
                              if (!snapshot.hasData ||
                                  snapshot.data!.docs.isEmpty) {
                                return const Center(
                                    child: Text('No visits found'));
                              }
                              // Filtering logic for visit cards
                              final filteredVisits = snapshot.data!.docs.where((
                                  doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final searchVal = _visitSearch.toLowerCase();
                                final matchesSearch = searchVal.isEmpty
                                    || (data['patientName'] ?? '')
                                        .toString()
                                        .toLowerCase()
                                        .contains(searchVal)
                                    || (data['patientId'] ?? '')
                                        .toString()
                                        .toLowerCase()
                                        .contains(searchVal)
                                    || (data['visitType'] ?? '')
                                        .toString()
                                        .toLowerCase()
                                        .contains(searchVal);

                                final matchesType = _visitType == 'All'
                                    || (data['visitType'] ?? '') == _visitType;

                                final matchesStatus = _visitStatus == 'All'
                                    || (data['status'] ?? '') == _visitStatus;

                                // Date range filter logic
                                // visitDate field is assumed to be ISO yyyy-MM-dd or yyyy-MM-ddTHH:mm:ss
                                DateTime? visitDate;
                                final visitDateStr = (data['visitDate'] ?? '')
                                    .toString();
                                if (visitDateStr.isNotEmpty) {
                                  try {
                                    visitDate = DateTime.tryParse(visitDateStr);
                                  } catch (_) {
                                    visitDate = null;
                                  }
                                }
                                bool matchesFrom = _visitDateFrom == null ||
                                    (visitDate != null &&
                                        !visitDate.isBefore(_visitDateFrom!));
                                bool matchesTo = _visitDateTo == null ||
                                    (visitDate != null &&
                                        !visitDate.isAfter(_visitDateTo!));

                                return matchesSearch && matchesType &&
                                    matchesStatus && matchesFrom && matchesTo;
                              }).toList();

                              if (filteredVisits.isEmpty) {
                                return const Center(child: Text(
                                    'No visits match these filters.'));
                              }
                              return ListView(
                                children: filteredVisits.map((doc) =>
                                    _buildVisitCard(context, doc)).toList(),
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
          ],
        ),
      ),
    );
  }
}
