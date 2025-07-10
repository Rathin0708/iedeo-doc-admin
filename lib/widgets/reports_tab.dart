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

class _ReportsTabState extends State<ReportsTab> {
  String _selectedPeriod = 'This Week';
  String _selectedReportType = 'All Reports';

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminFirebaseService>(
      builder: (context, firebaseService, child) {
        if (firebaseService.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

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
                            setState(() {
                              _selectedPeriod = value!;
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
                            'Visits by Therapist',
                            'Pending Follow-ups',
                            'Revenue Report'
                          ].map((type) =>
                              DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedReportType = value!;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () =>
                            _exportToPDF(context, firebaseService),
                        icon: const Icon(Icons.picture_as_pdf, size: 18),
                        label: const Text('Export PDF'),
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
                    if (_selectedReportType == 'All Reports' ||
                        _selectedReportType == 'Referrals by Doctor')
                      _buildReferralsByDoctorReport(firebaseService),
                    if (_selectedReportType == 'All Reports' ||
                        _selectedReportType == 'Visits by Therapist')
                      _buildVisitsByTherapistReport(firebaseService),
                    if (_selectedReportType == 'All Reports' ||
                        _selectedReportType == 'Pending Follow-ups')
                      _buildPendingFollowupsReport(firebaseService),
                    if (_selectedReportType == 'All Reports' ||
                        _selectedReportType == 'Revenue Report')
                      _buildRevenueReport(firebaseService),
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
            'Pending Follow-ups',
            '${firebaseService.dashboardStats['pendingFollowups'] ?? 0}',
            Icons.schedule,
            [Colors.orange[400]!, Colors.orange[600]!],
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

  Widget _buildReferralsByDoctorReport(AdminFirebaseService firebaseService) {
    final referralsData = firebaseService
        .reportData['referralsByDoctor'] as List<Map<String, dynamic>>? ?? [];

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
                  'Referrals by Doctor',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (referralsData.isEmpty)
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
              Container(
                width: double.infinity,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Doctor Name')),
                    DataColumn(label: Text('Total Referrals')),
                    DataColumn(label: Text('Completed')),
                    DataColumn(label: Text('Pending')),
                  ],
                  rows: referralsData.map((doctor) {
                    return DataRow(cells: [
                      DataCell(Text(doctor['doctorName'] ?? 'Unknown')),
                      DataCell(Text('${doctor['totalReferrals'] ?? 0}')),
                      DataCell(Text('${doctor['completed'] ?? 0}')),
                      DataCell(Text('${doctor['pending'] ?? 0}')),
                    ]);
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitsByTherapistReport(AdminFirebaseService firebaseService) {
    final visitsData = firebaseService.reportData['visitsByTherapist'] as List<
        Map<String, dynamic>>? ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.healing, color: Colors.green[700]),
                const SizedBox(width: 8),
                Text(
                  'Visits by Therapist',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (visitsData.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'No visit data available',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Therapist Name')),
                    DataColumn(label: Text('Total Visits')),
                    DataColumn(label: Text('This Week')),
                    DataColumn(label: Text('Completion Rate')),
                  ],
                  rows: visitsData.map((therapist) {
                    return DataRow(cells: [
                      DataCell(Text(therapist['therapistName'] ?? 'Unknown')),
                      DataCell(Text('${therapist['totalVisits'] ?? 0}')),
                      DataCell(Text('${therapist['thisWeekVisits'] ?? 0}')),
                      DataCell(Text('${therapist['completionRate'] ?? 0}%')),
                    ]);
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingFollowupsReport(AdminFirebaseService firebaseService) {
    final followupsData = firebaseService
        .reportData['pendingFollowups'] as List<Map<String, dynamic>>? ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Text(
                  'Pending Follow-ups',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (followupsData.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'No pending follow-ups',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Patient Name')),
                    DataColumn(label: Text('Therapist')),
                    DataColumn(label: Text('Last Visit')),
                    DataColumn(label: Text('Due Date')),
                  ],
                  rows: followupsData.map((followup) {
                    return DataRow(cells: [
                      DataCell(Text(followup['patientName'] ?? 'Unknown')),
                      DataCell(Text(followup['therapistName'] ?? 'Unknown')),
                      DataCell(Text(followup['lastVisitDate'] ?? 'Unknown')),
                      DataCell(Text(followup['dueDate'] ?? 'Unknown')),
                    ]);
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueReport(AdminFirebaseService firebaseService) {
    final revenueData = firebaseService.reportData['revenueData'] as Map<
        String,
        dynamic>? ?? {};

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
                  'Revenue Estimates',
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
                      color: Colors.purple[50],
                      borderRadius: BorderRadius.circular(8),
                      border: BoxBorder.lerp(
                        Border.all(color: Colors.purple[200]!),
                        Border.all(color: Colors.purple[200]!),
                        1.0,
                      )!,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'This Week',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.purple[800],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${revenueData['thisWeek'] ?? 0}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple[700],
                          ),
                        ),
                        Text(
                          '${revenueData['thisWeekVisits'] ??
                              0} visits completed',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.purple[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: BoxBorder.lerp(
                        Border.all(color: Colors.blue[200]!),
                        Border.all(color: Colors.blue[200]!),
                        1.0,
                      )!,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'This Month',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[800],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${revenueData['thisMonth'] ?? 0}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                        Text(
                          '${revenueData['thisMonthVisits'] ??
                              0} visits completed',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[600],
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

  List<List<String>> buildExportRows(AdminFirebaseService firebaseService,
      String reportType) {
    final List<List<String>> rows = [];
    if (reportType == 'Referrals by Doctor') {
      rows.add(['Doctor Name', 'Total Referrals', 'Completed', 'Pending']);
      final data = firebaseService.reportData['referralsByDoctor'] as List<
          Map<String, dynamic>>? ?? [];
      for (final row in data) {
        rows.add([
          row['doctorName'] ?? '',
          '${row['totalReferrals'] ?? 0}',
          '${row['completed'] ?? 0}',
          '${row['pending'] ?? 0}',
        ]);
      }
    } else if (reportType == 'Visits by Therapist') {
      rows.add(
          ['Therapist Name', 'Total Visits', 'This Week', 'Completion Rate']);
      final data = firebaseService.reportData['visitsByTherapist'] as List<
          Map<String, dynamic>>? ?? [];
      for (final row in data) {
        rows.add([
          row['therapistName'] ?? '',
          '${row['totalVisits'] ?? 0}',
          '${row['thisWeekVisits'] ?? 0}',
          '${row['completionRate'] ?? 0}%',
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
      rows.add(['Metric', 'This Week', 'This Month']);
      final revenue = firebaseService.reportData['revenueData'] as Map<
          String,
          dynamic>? ?? {};
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
      if (dataR.isNotEmpty) {
        rows.add(['Doctor Name', 'Total Referrals', 'Completed', 'Pending']);
        for (final row in dataR) {
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
            ['Therapist Name', 'Total Visits', 'This Week', 'Completion Rate']);
        for (final row in dataV) {
          rows.add([
            row['therapistName'] ?? '',
            '${row['totalVisits'] ?? 0}',
            '${row['thisWeekVisits'] ?? 0}',
            '${row['completionRate'] ?? 0}%',
          ]);
        }
        rows.add(List<String>.filled(4, ''));
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
      final rows = buildExportRows(firebaseService, _selectedReportType);
      final fontData = await rootBundle.load(
          'assets/fonts/NotoSans-Regular.ttf');
      final ttf = pw.Font.ttf(fontData.buffer.asByteData());
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          build: (context) =>
          [
            pw.Text('$_selectedReportType ($_selectedPeriod)',
                style: pw.TextStyle(
                    font: ttf, fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: rows.isNotEmpty ? rows[0] : [],
              data: rows.length > 1 ? rows.sublist(1).where((row) =>
              row.isNotEmpty).toList() : [],
              headerStyle: pw.TextStyle(
                  font: ttf, fontWeight: pw.FontWeight.bold),
              cellStyle: pw.TextStyle(font: ttf, fontSize: 11),
              headerDecoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#E3F2FD')),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ],
        ),
      );
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