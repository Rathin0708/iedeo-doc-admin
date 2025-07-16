import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/admin_firebase_service.dart';
import 'package:printing/printing.dart';

// PDF export dependencies
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart'; // For PdfColor, PdfPageFormat
import 'package:flutter/services.dart' show rootBundle;

class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> with AutomaticKeepAliveClientMixin {
  // Override to keep the tab state alive when switching tabs
  @override
  bool get wantKeepAlive => true;
  String _selectedPeriod = 'This Week';
  String _selectedReportType = 'All Reports';

  // Hold patient report data locally to avoid flicker or clearing on rebuild
  List<Map<String, dynamic>> _localPatientReport = [];
  bool _patientReportLoaded = false;

  // Helper: Parse a date value from Firestore or string
  DateTime? _parseVisitDate(dynamic d) {
    // Handle null, empty strings, or 'Not visited yet' text
    if (d == null) return null;
    if (d is String) {
      if (d.isEmpty || d == 'Not visited yet' || d == '-') {
        return null;
      }
    }
    if (d is DateTime) return d;
    
    // Handle Timestamp objects from Firestore
    try {
      return d.toDate();
    } catch (_) {}
    
    // Handle ISO date strings
    try {
      return DateTime.parse(d.toString());
    } catch (_) {}
    
    // Handle date strings in format YYYY-MM-DD
    try {
      final parts = d.toString().split('-');
      if (parts.length == 3) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (_) {}
    
    // Handle date strings in format DD/MM/YYYY
    try {
      final parts = d.toString().split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (_) {}
    
    // Only log unexpected formats that should be dates but can't be parsed
    if (d.toString().isNotEmpty && d.toString() != 'Not visited yet' && d.toString() != '-') {
      print('Failed to parse date: $d');
    }
    return null;
  }

  /// Returns a tuple (start, end) for the selected filter period
  List<DateTime> _getPeriodRange(String period) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    if (period == 'Today') {
      return [todayStart, todayStart.add(const Duration(days: 1))];
    } else if (period == 'This Week') {
      final weekStart = todayStart.subtract(
          Duration(days: todayStart.weekday - 1));
      return [weekStart, todayStart.add(const Duration(days: 1))];
    } else if (period == 'This Month') {
      final monthStart = DateTime(now.year, now.month, 1);
      return [monthStart, todayStart.add(const Duration(days: 1))];
    } else if (period == 'Last Month') {
      final lastMonth = now.month == 1 ? 12 : now.month - 1;
      final year = now.month == 1 ? now.year - 1 : now.year;
      final lastMonthStart = DateTime(year, lastMonth, 1);
      final lastMonthEnd = DateTime(now.year, now.month, 1);
      return [lastMonthStart, lastMonthEnd];
    } else {
      // Custom Range: fallback to 'This Week'
      final weekStart = todayStart.subtract(
          Duration(days: todayStart.weekday - 1));
      return [weekStart, todayStart.add(const Duration(days: 1))];
    }
  }

  @override
  void initState() {
    super.initState();
    // Fetch real patient report data only once when widget is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final service = Provider.of<AdminFirebaseService>(context, listen: false);
      await service.fetchPatientReport();
      // Save data locally if not already done (prevents re-clearing)
      if (mounted) {
        setState(() {
          _localPatientReport = List<Map<String, dynamic>>.from(
              service.reportData['patientReport'] ?? []);
          _patientReportLoaded = true;
        });
      }
    });
  }

  // Call this to manually refresh data on request
  Future<void> _refreshPatientReport(AdminFirebaseService service) async {
    if (!mounted) return;
    
    setState(() {
      _patientReportLoaded = false;
    });
    
    await service.fetchPatientReport();
    
    if (mounted) {
      setState(() {
        _localPatientReport = List<Map<String, dynamic>>.from(
            service.reportData['patientReport'] ?? []);
        _patientReportLoaded = true;
        
        // Debug output to check patient data structure
        if (_localPatientReport.isNotEmpty) {
          print('First patient in _localPatientReport: ${_localPatientReport.first}');
        } else {
          print('No patients in _localPatientReport');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Consumer<AdminFirebaseService>(
      builder: (context, firebaseService, child) {
        if (firebaseService.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        // Wait until all reports, especially allVisits, are actually loaded
        final bool isRevenueReady =
            !firebaseService.isLoading &&
                (firebaseService.reportData['allVisits'] != null) &&
                (firebaseService.reportData['allVisits'] as List).isNotEmpty;

        return Column(
          children: [
            // Sticky Reports Header
            Container(
              color: Colors.grey[50],
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Report Title and Period Selector
                  Row(
                    children: [
                      Icon(Icons.bar_chart, color: Colors.blue[700], size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Admin Reports',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.schedule, size: 16,
                                color: Colors.blue[700]),
                            const SizedBox(width: 4),
                            Text(
                              _selectedPeriod,
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Filter Row
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Report Period',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          value: _selectedPeriod,
                          items: [
                            'Today',
                            'This Week',
                            'This Month',
                            'Last Month',
                            'Custom Range'
                          ]
                              .map((period) =>
                              DropdownMenuItem(
                                value: period,
                                child: Text(period),
                              ))
                              .toList(),
                          onChanged: (value) {
                            if (value == _selectedPeriod) return;
                            
                            // Use microtask to defer state update to next frame
                            Future.microtask(() {
                              if (mounted) {
                                setState(() {
                                  _selectedPeriod = value!;
                                });
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Report Type',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          value: _selectedReportType,
                          items: [
                            'All Reports',
                            'Referrals by Doctor',
                            'Revenue Report',
                            'Patient Report',
                          ].map((type) =>
                              DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              ))
                              .toList(),
                          onChanged: (value) {
                            if (value == _selectedReportType) return;
                            
                            // Use microtask to defer state update to next frame
                            Future.microtask(() {
                              if (mounted) {
                                setState(() {
                                  _selectedReportType = value!;
                                });
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: isRevenueReady
                            ? () => _exportToPDF(context, firebaseService)
                            : null, // disable until data loaded
                        icon: const Icon(Icons.picture_as_pdf, size: 18),
                        label: isRevenueReady
                            ? const Text('Export PDF')
                            : Row(children: [
                          SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2)),
                          SizedBox(width: 8),
                          Text('Loading...')
                        ]),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[400],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Scrollable Reports Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Quick Stats Cards
                    _buildQuickStatsRow(firebaseService),
                    const SizedBox(height: 20),

                    // Reports Based on Selection
                    Builder(
                      builder: (_) {
                        // Only show the selected report section/page at a time.
                        if (_selectedReportType == 'All Reports') {
                          // Show all topics; each in its own card and heading.
                          return Column(
                            children: [
                              _buildReferralsByDoctorReport(firebaseService),

                              _buildPatientReport(firebaseService),
                              _buildRevenueReport(firebaseService),
                            ],
                          );
                        } else
                        if (_selectedReportType == 'Referrals by Doctor') {
                          return _buildReferralsByDoctorReport(firebaseService);
                        }
                         else if (_selectedReportType == 'Revenue Report') {
                          return _buildRevenueReport(firebaseService);
                        } else if (_selectedReportType == 'Patient Report') {
                          return _buildPatientReport(firebaseService);
                        }  else {
                          // Fallback empty space for future types
                          return const SizedBox.shrink();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickStatsRow(AdminFirebaseService firebaseService) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Referrals',
            '${firebaseService.dashboardStats['totalReferrals'] ?? 0}',
            Icons.person_add,
            [Colors.blue[400]!, Colors.blue[600]!],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Completed Visits',
            '${firebaseService.dashboardStats['completedVisits'] ?? 0}',
            Icons.check_circle,
            [Colors.green[400]!, Colors.green[600]!],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Revenue ($_selectedPeriod)',
            '₹${firebaseService.dashboardStats['estimatedRevenue'] ?? 0}',
            Icons.attach_money,
            [Colors.purple[400]!, Colors.purple[600]!],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon,
      List<Color> gradientColors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradientColors),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: gradientColors[1],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Track how many doctors to show in the referrals report
  int _doctorDisplayLimit = 10;
  bool _showingAllDoctors = false;
  
  Widget _buildReferralsByDoctorReport(AdminFirebaseService firebaseService) {
    final allReferrals = firebaseService
        .reportData['referralsByDoctor'] as List<Map<String, dynamic>>? ?? [];

    // Filter referrals by period using period range
    final List<Map<String, dynamic>> referralsFiltered = allReferrals.where((
        row) {
      // Can't filter by individual visit date: needs visit/createdAt field
      // Here, we try to use the 'createdAt' field in each referral by doctor row
      final createdAt = _parseVisitDate(row['createdAt']);
      if (createdAt == null) return true; // Fallback: if missing, include
      final range = _getPeriodRange(_selectedPeriod);
      return !createdAt.isBefore(range[0]) && createdAt.isBefore(range[1]);
    }).toList();
    
    // Determine if we need to show the View More button
    final hasMoreDoctors = referralsFiltered.length > _doctorDisplayLimit;
    // Get the doctors to display based on the current limit
    final doctorsToDisplay = hasMoreDoctors && !_showingAllDoctors
        ? referralsFiltered.take(_doctorDisplayLimit).toList()
        : referralsFiltered;

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.medical_services, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'Referrals by Doctor (${_selectedPeriod})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (referralsFiltered.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'No referral data available',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Doctor Name')),
                        DataColumn(label: Text('Total Referrals')),
                        DataColumn(label: Text('Completed')),
                        DataColumn(label: Text('Pending')),
                      ],
                      rows: doctorsToDisplay.map((doctor) {
                        return DataRow(cells: [
                          DataCell(Text(doctor['doctorName'] ?? 'Unknown')),
                          DataCell(Text('${doctor['totalReferrals'] ?? 0}')),
                          DataCell(Text('${doctor['completed'] ?? 0}')),
                          DataCell(Text('${doctor['pending'] ?? 0}')),
                        ]);
                      }).toList(),
                    ),
                  ),
                  // Show View More button if there are more doctors
                  if (hasMoreDoctors)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _showingAllDoctors = !_showingAllDoctors;
                          });
                        },
                        child: Text(
                          _showingAllDoctors ? 'Show Less' : 'View More (${referralsFiltered.length - _doctorDisplayLimit} more)',
                          style: TextStyle(color: Colors.blue[700]),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueReport(AdminFirebaseService firebaseService) {
    final List<Map<String, dynamic>> allVisits = firebaseService
        .reportData['allVisits'] as List<Map<String, dynamic>>? ?? [];
    final periodRange = _getPeriodRange(_selectedPeriod);
    final periodStart = periodRange[0];
    final periodEnd = periodRange[1];
    // Use the selected filter for summary revenue calculation
    final filteredVisits = allVisits.where((v) {
      final dt = _parseVisitDate(v['visitDate']);
      return dt != null && !dt.isBefore(periodStart) && dt.isBefore(periodEnd);
    }).toList();
    final double totalRevenue = filteredVisits.fold(0.0, (sum, v) =>
    sum +
        (double.tryParse(v['amount']?.toString() ?? '0') ?? 0));
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.attach_money, color: Colors.purple[700]),
                const SizedBox(width: 8),
                Text(
                  'Revenue - $_selectedPeriod',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.teal[50],
                      borderRadius: BorderRadius.circular(8),
                      border: BoxBorder.lerp(
                        Border.all(color: Colors.teal[200]!),
                        Border.all(color: Colors.teal[200]!),
                        1.0,
                      )!,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedPeriod,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.teal[800],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${totalRevenue.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal[700],
                          ),
                        ),
                        Text(
                          '${filteredVisits.length} visits completed',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.teal[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Track how many patients to show in the report
  int _patientDisplayLimit = 10;
  bool _showingAllPatients = false;
  
  Widget _buildPatientReport(AdminFirebaseService firebaseService) {
    // Patient report comes from _localPatientReport, but add filter based on 'lastVisit' date string
    final patientsFiltered = _localPatientReport.where((patient) {
      final lastVisit = _parseVisitDate(patient['lastVisit']);
      if (lastVisit == null) return true; // Fallback
      final range = _getPeriodRange(_selectedPeriod);
      return !lastVisit.isBefore(range[0]) && lastVisit.isBefore(range[1]);
    }).toList();
    
    // Determine if we need to show the View More button
    final hasMorePatients = patientsFiltered.length > _patientDisplayLimit;
    // Get the patients to display based on the current limit
    final patientsToDisplay = hasMorePatients && !_showingAllPatients
        ? patientsFiltered.take(_patientDisplayLimit).toList()
        : patientsFiltered;
    // ... rest of card code, substitute 'patients' with 'patientsFiltered' in DataTable
    bool debugMode = true; // Set to true for extra debugging UI
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Colors.teal[700]),
                const SizedBox(width: 8),
                Text(
                  'Patient Report ($_selectedPeriod)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                // Manual refresh button if needed
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.refresh, color: Colors.teal[700], size: 20),
                  tooltip: 'Refresh Patient Report',
                  onPressed: () => _refreshPatientReport(firebaseService),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!_patientReportLoaded) ...[
              // Show progress while loading/refetching patient data only
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 10),
            ],
            if (debugMode) ...[
              // Shows patient report list length for quick checking
              Text('Patient report data count: ${patientsFiltered.length}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              // List out the first patient data map for visual debugging
              if (patientsFiltered.isNotEmpty)
                Text('First patient data: ${patientsFiltered.first.toString()}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]))
              else
                Text('No patient data received from service',
                    style: TextStyle(fontSize: 11, color: Colors.red)),
              const Divider(),
            ],
            if (_patientReportLoaded && patientsFiltered.isEmpty)
            // Graceful message for empty state
              Container(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'No patient data available',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else
              if (_patientReportLoaded)
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    // DataTable renders the patient details
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Patient Name')),
                        DataColumn(label: Text('Therapist')),
                        DataColumn(label: Text('Doctor')),
                        DataColumn(label: Text('Last Visit')),
                      ],
                      rows: patientsToDisplay.map((patient) {
                        return DataRow(cells: [
                          DataCell(Text(getDisplayPatientName(patient))),
                          DataCell(Text(patient['therapist'] ?? 'Unknown')),
                          DataCell(Text(patient['doctor'] ?? 'Unknown')),
                          DataCell(Text(patient['lastVisit'] ?? '-')),
                        ]);
                      }).toList(),
                    ),
                  ),
                  // Show View More button if there are more patients
                  if (hasMorePatients)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _showingAllPatients = !_showingAllPatients;
                          });
                        },
                        child: Text(
                          _showingAllPatients ? 'Show Less' : 'View More (${patientsFiltered.length - _patientDisplayLimit} more)',
                          style: TextStyle(color: Colors.teal[700]),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // Utility: Get real patient display name from a map (tries 'patientName', then 'name', then 'fullName', then fallback to 'Unknown')
  String getDisplayPatientName(Map<String, dynamic> patient) {
    // Try all possible keys in priority order - patientName first as it's the primary key in the Firebase data
    final String n = (patient['patientName'] ?? patient['name'] ??
        patient['fullName'] ?? '').toString().trim();
    
    // Debug the patient data if name is empty
    if (n.isEmpty) {
      print('Patient data with missing name: $patient');
    }
    
    return n.isNotEmpty ? n : 'Unknown';
  }

  List<List<String>> buildExportRows(AdminFirebaseService firebaseService,
      String reportType, {List<Map<String, dynamic>>? patientReportOverride}) {
    final List<List<String>> rows = [];
    if (reportType == 'Referrals by Doctor') {
      rows.add(['Doctor Name', 'Total Referrals', 'Completed', 'Pending']);
      final data = firebaseService.reportData['referralsByDoctor'] as List<
          Map<String, dynamic>>? ?? [];
      final period = _selectedPeriod;
      final range = _getPeriodRange(period);
      for (final row in data) {
        // Filter based on createdAt in export too
        final createdAt = _parseVisitDate(row['createdAt']);
        if (createdAt != null &&
            (createdAt.isBefore(range[0]) || !createdAt.isBefore(range[1]))) {
          continue;
        }
        rows.add([
          row['doctorName'] ?? '',
          '${row['totalReferrals'] ?? 0}',
          '${row['completed'] ?? 0}',
          '${row['pending'] ?? 0}',
        ]);
      }
    } else if (reportType == 'Visits by Therapist') {
      rows.add(
          ['Therapist Name', 'Total Visits', 'Completion Rate']);
      final allVisits = firebaseService.reportData['allVisits'] as List<
          Map<String, dynamic>>? ?? [];
      final allTherapistStats = firebaseService
          .reportData['visitsByTherapist'] as List<Map<String, dynamic>>? ?? [];
      final period = _selectedPeriod;
      final range = _getPeriodRange(period);
      Map<String, Map<String, dynamic>> periodTherapists = {};
      for (final visit in allVisits) {
        final therapistId = visit['therapistId'];
        final visitDate = _parseVisitDate(visit['visitDate']);
        if (therapistId == null || visitDate == null) continue;
        if (!visitDate.isBefore(range[0]) && visitDate.isBefore(range[1])) {
          periodTherapists.putIfAbsent(therapistId, () {
            final mainRow = allTherapistStats.firstWhere(
                    (row) => row['therapistId'] == therapistId,
                orElse: () => {});
            return {
              'therapistName': mainRow['therapistName'] ?? 'Unknown',
              'therapistId': therapistId,
              'totalVisits': 0,
              'completionRate': mainRow['completionRate'] ?? 0,
              'thisWeekVisits': mainRow['thisWeekVisits'] ?? 0,
            };
          });
          periodTherapists[therapistId]!['totalVisits']++;
        }
      }
      final visitsFiltered = periodTherapists.values.toList();
      for (final row in visitsFiltered) {
        rows.add([
          row['therapistName'] ?? '',
          '${row['totalVisits'] ?? 0}',
          '${row['completionRate'] ?? 0}%'
        ]);
      }
    } else if (reportType == 'Pending Follow-ups') {
      rows.add(['Patient Name', 'Therapist', 'Last Visit', 'Due Date']);
      final data = firebaseService.reportData['pendingFollowups'] as List<
          Map<String, dynamic>>? ?? [];
      for (final row in data) {
        rows.add([
          row['patientName'] ?? '',
          row['therapistName'] ?? '',
          row['lastVisitDate'] ?? '',
          row['dueDate'] ?? '',
        ]);
      }
    } else if (reportType == 'Revenue Report') {
      // Export must match filter!
      final List<Map<String, dynamic>> allVisits = firebaseService
          .reportData['allVisits'] as List<Map<String, dynamic>>? ?? [];
      final filterPeriod = _selectedPeriod;
      final periodRange = _getPeriodRange(filterPeriod);
      final periodStart = periodRange[0];
      final periodEnd = periodRange[1];
      final filteredVisits = allVisits.where((v) {
        final dt = _parseVisitDate(v['visitDate']);
        return dt != null && !dt.isBefore(periodStart) &&
            dt.isBefore(periodEnd);
      }).toList();
      final double totalRevenue = filteredVisits.fold(0.0, (sum, v) =>
      sum +
          (double.tryParse(v['amount']?.toString() ?? '0') ?? 0));
      rows.add(['Metric', _selectedPeriod]);
      rows.add(['Revenue', '₹${totalRevenue.toStringAsFixed(2)}']);
      rows.add(['Visits', '${filteredVisits.length}']);
    } else if (reportType == 'Patient Report') {
      // Use patientReportOverride if provided, else fallback to firebaseService
      final data = patientReportOverride ??
          firebaseService.reportData['patientReport'] as List<
              Map<String, dynamic>>? ?? [];
      final period = _selectedPeriod;
      final range = _getPeriodRange(period);
      rows.add(['Patient Name', 'Therapist', 'Doctor', 'Last Visit']);
      for (final row in data) {
        final lastVisit = _parseVisitDate(row['lastVisit']);
        if (lastVisit != null &&
            (lastVisit.isBefore(range[0]) || !lastVisit.isBefore(range[1]))) {
          continue;
        }
        rows.add([
          getDisplayPatientName(row),
          // Use patientName if present, else name, else blank. Ensures correct export display even if Firestore/old data mixes key names.
          row['therapist'] ?? '',
          row['doctor'] ?? '',
          row['lastVisit'] ?? '',
        ]);
      }
    } else if (reportType == 'Visit Log Report') {
      rows.add([
        'Patient Name',
        'Patient ID',
        'Therapist',
        'Visit Date',
        'Visit Time',
        'Visit Type',
        'Status',
        'VAS',
        'Amount',
        'Follow Up',
        'Treatment Notes',
        'Progress Notes',
        'Notes',
        'Created At'
      ]);
      final data = firebaseService.reportData['visitLog'] as List<
          Map<String, dynamic>>? ?? [];
      double sum = 0;
      for (final v in data) {
        final amt = double.tryParse(v['amount']?.toString() ?? '0') ?? 0;
        sum += amt;
        rows.add([
          v['patientName'] ?? '',
          v['patientId'] ?? '',
          v['therapist'] ?? '-',
          v['visitDate'] ?? '',
          v['visitTime'] ?? '',
          v['visitType'] ?? '',
          v['status'] ?? '',
          v['vasScore']?.toString() ?? '',
          v['amount']?.toString() ?? '',
          (v['followUpRequired'] ?? false) ? 'Yes' : 'No',
          v['treatmentNotes'] ?? '',
          v['progressNotes'] ?? '',
          v['notes'] ?? '',
          v['createdAt'] ?? '',
        ]);
      }
      // Total row
      if (data.isNotEmpty) {
        rows.add(List.filled(7, '')); // for spacing
        rows.add(['', '', '', '', '', '', '', 'TOTAL', sum.toStringAsFixed(2)] +
            List.filled(5, ''));
      }
    } else { // All Reports: concatenate all
      final dataR = firebaseService.reportData['referralsByDoctor'] as List<
          Map<String, dynamic>>? ?? [];
      final dataV = firebaseService.reportData['visitsByTherapist'] as List<
          Map<String, dynamic>>? ?? [];
      final dataF = firebaseService.reportData['pendingFollowups'] as List<
          Map<String, dynamic>>? ?? [];
      final revenue = firebaseService.reportData['revenueData'] as Map<
          String,
          dynamic>? ?? {};
      final allVisits = firebaseService.reportData['allVisits'] as List<
          Map<String, dynamic>>? ?? [];
      final allTherapistStats = dataV;
      if (dataR.isNotEmpty) {
        rows.add(['Doctor Name', 'Total Referrals', 'Completed', 'Pending']);
        final period = _selectedPeriod;
        final range = _getPeriodRange(period);
        for (final row in dataR) {
          final createdAt = _parseVisitDate(row['createdAt']);
          if (createdAt != null &&
              (createdAt.isBefore(range[0]) || !createdAt.isBefore(range[1]))) {
            continue;
          }
          rows.add([
            row['doctorName'] ?? '',
            '${row['totalReferrals'] ?? 0}',
            '${row['completed'] ?? 0}',
            '${row['pending'] ?? 0}',
          ]);
        }
        rows.add(List<String>.filled(4, ''));
      }
      if (dataV.isNotEmpty) {
        rows.add(
            ['Therapist Name', 'Total Visits', 'Completion Rate']);
        final period = _selectedPeriod;
        final range = _getPeriodRange(period);
        Map<String, Map<String, dynamic>> periodTherapists = {};
        for (final visit in allVisits) {
          final therapistId = visit['therapistId'];
          final visitDate = _parseVisitDate(visit['visitDate']);
          if (therapistId == null || visitDate == null) continue;
          if (!visitDate.isBefore(range[0]) && visitDate.isBefore(range[1])) {
            periodTherapists.putIfAbsent(therapistId, () {
              final mainRow = allTherapistStats.firstWhere(
                      (row) => row['therapistId'] == therapistId,
                  orElse: () => {});
              return {
                'therapistName': mainRow['therapistName'] ?? 'Unknown',
                'therapistId': therapistId,
                'totalVisits': 0,
                'completionRate': mainRow['completionRate'] ?? 0,
              };
            });
            periodTherapists[therapistId]!['totalVisits']++;
          }
        }
        final visitsFiltered = periodTherapists.values.toList();
        for (final row in visitsFiltered) {
          rows.add([
            row['therapistName'] ?? '',
            '${row['totalVisits'] ?? 0}',
            '${row['completionRate'] ?? 0}%',
          ]);
        }
        rows.add(List<String>.filled(3, ''));
      }
      if (dataF.isNotEmpty) {
        rows.add(['Patient Name', 'Therapist', 'Last Visit', 'Due Date']);
        for (final row in dataF) {
          rows.add([
            row['patientName'] ?? '',
            row['therapistName'] ?? '',
            row['lastVisitDate'] ?? '',
            row['dueDate'] ?? '',
          ]);
        }
        rows.add(List<String>.filled(4, ''));
      }
      if (revenue.isNotEmpty) {
        rows.add(['Metric', 'This Week', 'This Month']);
        rows.add([
          'Revenue',
          '₹${revenue['thisWeek'] ?? 0}',
          '₹${revenue['thisMonth'] ?? 0}'
        ]);
        rows.add([
          'Visits',
          '${revenue['thisWeekVisits'] ?? 0}',
          '${revenue['thisMonthVisits'] ?? 0}'
        ]);
        rows.add(List<String>.filled(3, ''));
      }
      // For All Reports export, also use the local version for patient report if available
      final patientExport = patientReportOverride ??
          firebaseService.reportData['patientReport'] as List<
              Map<String, dynamic>>? ?? [];
      final period = _selectedPeriod;
      final range = _getPeriodRange(period);
      if (patientExport.isNotEmpty) {
        rows.add(['Patient Name', 'Therapist', 'Doctor', 'Last Visit']);
        for (final row in patientExport) {
          final lastVisit = _parseVisitDate(row['lastVisit']);
          if (lastVisit != null &&
              (lastVisit.isBefore(range[0]) || !lastVisit.isBefore(range[1]))) {
            continue;
          }
          rows.add([
            getDisplayPatientName(row),
            // Use patientName if present, else name, else blank. Ensures correct export display even if Firestore/old data mixes key names.
            row['therapist'] ?? '',
            row['doctor'] ?? '',
            row['lastVisit'] ?? '',
          ]);
        }
        rows.add(List<String>.filled(4, ''));
      }
      final vRowsLog = buildExportRows(firebaseService, 'Visit Log Report');
      if (vRowsLog.length > 1) {
        rows.addAll(vRowsLog);
      }
    }
    return rows;
  }

  Future<void> _exportToPDF(BuildContext context,
      AdminFirebaseService firebaseService) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final fontData = await rootBundle.load(
          'assets/fonts/NotoSans-Regular.ttf');
      final ttf = pw.Font.ttf(fontData.buffer.asByteData());
      final pdf = pw.Document();
      pw.Widget buildSection({required String heading, required List<
          String> headers, required List<
          List<String>> dataRows, PdfColor? headerColor}) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(heading,
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#3954A4'),
                )),
            pw.SizedBox(height: 6),
            pw.Table.fromTextArray(
              headers: headers,
              data: dataRows,
              headerStyle: pw.TextStyle(
                  font: ttf, fontWeight: pw.FontWeight.bold),
              cellStyle: pw.TextStyle(font: ttf, fontSize: 11),
              headerDecoration: pw.BoxDecoration(
                color: headerColor ?? PdfColor.fromHex('#E3F2FD'),
              ),
              cellAlignment: pw.Alignment.centerLeft,
            ),
            pw.SizedBox(height: 24),
          ],
        );
      }
      final pageWidgets = <pw.Widget>[];
      if (_selectedReportType == 'All Reports') {
        final rRows = buildExportRows(firebaseService, 'Referrals by Doctor');
        if (rRows.length > 1) {
          pageWidgets.add(buildSection(
            heading: 'Referrals by Doctor',
            headers: rRows[0],
            dataRows: rRows
                .sublist(1)
                .where((row) => row.isNotEmpty)
                .toList(),
            headerColor: PdfColor.fromHex('#E3F2FD'),
          ));
        }
        final vRows = buildExportRows(firebaseService, 'Visits by Therapist');
        if (vRows.length > 1) {
          pageWidgets.add(buildSection(
            heading: 'Visits by Therapist',
            headers: vRows[0],
            dataRows: vRows
                .sublist(1)
                .where((row) => row.isNotEmpty)
                .toList(),
            headerColor: PdfColor.fromHex('#E8F5E9'),
          ));
        }



        final patRows = buildExportRows(firebaseService, 'Patient Report',
            patientReportOverride: _localPatientReport);
        if (patRows.length > 1) {
          pageWidgets.add(buildSection(
            heading: 'Patient Report',
            headers: patRows[0],
            dataRows: patRows
                .sublist(1)
                .where((row) => row.isNotEmpty)
                .toList(),
            headerColor: PdfColor.fromHex('#E0F2F1'),
          ));
        }
        final revRows = buildExportRows(firebaseService, 'Revenue Report');
        if (revRows.length > 1) {
          pageWidgets.add(buildSection(
            heading: 'Revenue Report',
            headers: revRows[0],
            dataRows: revRows
                .sublist(1)
                .where((row) => row.isNotEmpty)
                .toList(),
            headerColor: PdfColor.fromHex('#F3E5F5'),
          ));
        }
        pdf.addPage(
          pw.MultiPage(
            build: (context) =>
            [
              pw.Text('All Reports ($_selectedPeriod)', style: pw.TextStyle(
                  font: ttf, fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 12),
              ...pageWidgets,
            ],
          ),
        );
      } else {
        final rows = buildExportRows(firebaseService, _selectedReportType,
            patientReportOverride: _localPatientReport);
        if (rows.length > 1) {
          pdf.addPage(
            pw.MultiPage(
              build: (context) =>
              [
                pw.Text('$_selectedReportType ($_selectedPeriod)',
                    style: pw.TextStyle(font: ttf,
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 12),
                buildSection(
                  heading: _selectedReportType,
                  headers: rows[0],
                  dataRows: rows
                      .sublist(1)
                      .where((row) => row.isNotEmpty)
                      .toList(),
                ),
              ],
            ),
          );
        } else {
          pdf.addPage(
            pw.MultiPage(
              build: (context) =>
              [
                pw.Text('$_selectedReportType ($_selectedPeriod)',
                    style: pw.TextStyle(font: ttf,
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 12),
                pw.Text('No data to export.',
                    style: pw.TextStyle(font: ttf, fontSize: 14)),
              ],
            ),
          );
        }
      }
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: '${_selectedReportType.replaceAll(' ', '_')}_${DateTime
            .now()
            .millisecondsSinceEpoch}.pdf',
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('PDF file exported.'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('PDF export failed: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }
}