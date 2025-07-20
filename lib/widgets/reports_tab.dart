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
  // Default to showing the filter panel on initialization
  bool _isFilterExpanded = true;
  // Override to keep the tab state alive when switching tabs
  @override
  bool get wantKeepAlive => true;
  String _selectedPeriod = 'This Week';
  // Custom date range variables
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  String _selectedReportType = 'All Reports';
  
  // Additional filter options
  String? _selectedDoctor;
  String? _selectedTherapist;
  String? _selectedStatus;
  
  // Lists for filter dropdowns
  List<String> _doctorsList = ['All Doctors'];
  List<String> _therapistsList = ['All Therapists'];
  List<String> _statusList = ['All Status', 'Completed', 'Pending'];

  // Hold patient report data locally to avoid flicker or clearing on rebuild
  List<Map<String, dynamic>> _localPatientReport = [];
  bool _patientReportLoaded = false;

  // Format date for display
  String _formatDateForDisplay(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
  
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
    } else if (period == 'Custom Range' && _customStartDate != null && _customEndDate != null) {
      // Use the selected custom date range
      final customStart = DateTime(_customStartDate!.year, _customStartDate!.month, _customStartDate!.day);
      // Add 1 day to end date to include the full end date (up to midnight)
      final customEnd = DateTime(_customEndDate!.year, _customEndDate!.month, _customEndDate!.day)
          .add(const Duration(days: 1));
      return [customStart, customEnd];
    } else {
      // Fallback to 'This Week' if custom range is not properly set
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
          
          // Extract unique doctors and therapists from the data
          _loadFilterOptions();
        });
      }
    });
  }

  // Load filter options from data
  void _loadFilterOptions() {
    // Extract unique doctors from patient report
    Set<String> doctors = {'All Doctors'};
    Set<String> therapists = {'All Therapists'};
    
    for (var patient in _localPatientReport) {
      // Add doctor names
      if (patient['doctor'] != null && patient['doctor'].toString().isNotEmpty) {
        doctors.add(patient['doctor'].toString());
      }
      
      // Add therapist names
      if (patient['therapist'] != null && patient['therapist'].toString().isNotEmpty) {
        therapists.add(patient['therapist'].toString());
      }
    }
    
    // Get data from referrals by doctor report
    final adminService = Provider.of<AdminFirebaseService>(context, listen: false);
    final referralsByDoctor = adminService.reportData['referralsByDoctor'] as List<Map<String, dynamic>>? ?? [];
    
    for (var doctor in referralsByDoctor) {
      if (doctor['doctorName'] != null && doctor['doctorName'].toString().isNotEmpty) {
        doctors.add(doctor['doctorName'].toString());
      }
    }
    
    // Update the lists
    _doctorsList = doctors.toList()..sort();
    _therapistsList = therapists.toList()..sort();
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
        
        // Update filter options
        _loadFilterOptions();
        
        // Debug output to check patient data structure
        if (_localPatientReport.isNotEmpty) {
          print('First patient in _localPatientReport: ${_localPatientReport.first}');
        } else {
          print('No patients in _localPatientReport');
        }
      });
    }
  }

  // Build a responsive filter panel that adapts to both mobile and web screens
  Widget _buildFilterPanel(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600; // Breakpoint for mobile devices
    
    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter Header with expand/collapse button
            InkWell(
              onTap: () {
                setState(() {
                  _isFilterExpanded = !_isFilterExpanded;
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Icon(Icons.filter_list, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const Spacer(),
                    // Period badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _selectedPeriod,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _isFilterExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey[600],
                    ),
                  ],
                ),
              ),
            ),
            
            // Expandable Filter Content
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState: _isFilterExpanded 
                  ? CrossFadeState.showSecond 
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox(height: 0),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    const SizedBox(height: 8),
                    
                    // Period Filter with Date Range Picker
                    Text(
                      'Report Period:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildPeriodChip('Today'),
                          const SizedBox(width: 8),
                          _buildPeriodChip('This Week'),
                          const SizedBox(width: 8),
                          _buildPeriodChip('This Month'),
                          const SizedBox(width: 8),
                          _buildPeriodChip('Last Month'),
                          const SizedBox(width: 8),
                          _buildPeriodChip('Custom Range'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Doctor, Therapist, Status filters
                    // Use responsive layout based on screen width
                    isMobile
                        ? _buildMobileFilters()
                        : _buildWebFilters(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Mobile-friendly stacked filter layout
  Widget _buildMobileFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Doctor Filter
        Text(
          'Doctor:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: ButtonTheme(
              alignedDropdown: true,
              child: DropdownButton<String>(
                value: _selectedDoctor ?? 'All Doctors',
                isExpanded: true,
                icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                items: _doctorsList
                    .map((doctor) => DropdownMenuItem(
                          value: doctor,
                          child: Text(doctor),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedDoctor = value == 'All Doctors' ? null : value;
                  });
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        
        // Therapist Filter
        Text(
          'Therapist:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: ButtonTheme(
              alignedDropdown: true,
              child: DropdownButton<String>(
                value: _selectedTherapist ?? 'All Therapists',
                isExpanded: true,
                icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                items: _therapistsList
                    .map((therapist) => DropdownMenuItem(
                          value: therapist,
                          child: Text(therapist),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedTherapist = value == 'All Therapists' ? null : value;
                  });
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        
        // Status Filter
        Text(
          'Status:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: ButtonTheme(
              alignedDropdown: true,
              child: DropdownButton<String>(
                value: _selectedStatus ?? 'All Status',
                isExpanded: true,
                icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                items: _statusList
                    .map((status) => DropdownMenuItem(
                          value: status,
                          child: Text(status),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedStatus = value == 'All Status' ? null : value;
                  });
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  // Web-friendly row layout for filters
  Widget _buildWebFilters() {
    return Row(
      children: [
        // Doctor Filter
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Doctor:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: ButtonTheme(
                    alignedDropdown: true,
                    child: DropdownButton<String>(
                      value: _selectedDoctor ?? 'All Doctors',
                      isExpanded: true,
                      icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      items: _doctorsList
                          .map((doctor) => DropdownMenuItem(
                                value: doctor,
                                child: Text(doctor),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedDoctor = value == 'All Doctors' ? null : value;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        
        // Therapist Filter
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Therapist:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: ButtonTheme(
                    alignedDropdown: true,
                    child: DropdownButton<String>(
                      value: _selectedTherapist ?? 'All Therapists',
                      isExpanded: true,
                      icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      items: _therapistsList
                          .map((therapist) => DropdownMenuItem(
                                value: therapist,
                                child: Text(therapist),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedTherapist = value == 'All Therapists' ? null : value;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        
        // Status Filter
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Status:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: ButtonTheme(
                    alignedDropdown: true,
                    child: DropdownButton<String>(
                      value: _selectedStatus ?? 'All Status',
                      isExpanded: true,
                      icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      items: _statusList
                          .map((status) => DropdownMenuItem(
                                value: status,
                                child: Text(status),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedStatus = value == 'All Status' ? null : value;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // Helper method to build period filter chips
  Widget _buildPeriodChip(String period) {
    final isSelected = _selectedPeriod == period;
    
    return GestureDetector(
      onTap: () async {
        if (period == _selectedPeriod) return;
        
        // If Custom Range is selected, show date picker
        if (period == 'Custom Range') {
          // Initialize with reasonable defaults if not set
          _customStartDate ??= DateTime.now().subtract(const Duration(days: 7));
          _customEndDate ??= DateTime.now();
          
          // Show date range picker
          final picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
            initialDateRange: DateTimeRange(
              start: _customStartDate!,
              end: _customEndDate!,
            ),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.light(
                    primary: Colors.teal[700]!, // Header background
                    onPrimary: Colors.white, // Header text
                    onSurface: Colors.black, // Calendar text
                  ),
                ),
                child: child!,
              );
            },
          );
          
          // If user cancels, revert to previous selection
          if (picked == null) {
            return;
          }
          
          // Update the custom date range
          _customStartDate = picked.start;
          _customEndDate = picked.end;
        }
        
        setState(() {
          _selectedPeriod = period;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[700] : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.blue[700]! : Colors.grey[300]!,
          ),
        ),
        child: Text(
          period,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[800],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
  
  // Helper method to build report type chips
  Widget _buildReportTypeChip(String reportType) {
    final isSelected = _selectedReportType == reportType;
    
    return GestureDetector(
      onTap: () {
        if (reportType == _selectedReportType) return;
        setState(() {
          _selectedReportType = reportType;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.teal[700] : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.teal[700]! : Colors.grey[300]!,
          ),
        ),
        child: Text(
          reportType,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[800],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
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
            // Sticky Reports Header with Responsive Filter Panel
            Container(
              color: Colors.grey[50],
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Report Title with Period Badge
                  Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.teal[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedPeriod == 'Custom Range' && _customStartDate != null && _customEndDate != null
                              ? 'Reports for Custom Range: ${_formatDateForDisplay(_customStartDate!)} - ${_formatDateForDisplay(_customEndDate!)}'
                              : 'Reports for $_selectedPeriod',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Export PDF Button - Always visible
                      ElevatedButton.icon(
                        onPressed: isRevenueReady
                            ? () => _exportToPDF(context, firebaseService)
                            : null, // disable until data loaded
                        icon: const Icon(Icons.picture_as_pdf, size: 18),
                        label: isRevenueReady
                            ? const Text('Export')
                            : SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(strokeWidth: 2)
                              ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[400],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Filter Section with Collapsible Panel
                  _buildFilterPanel(context),
                  
                  // Report Type Selector - Chip Style
                  const SizedBox(height: 16),
                  Text(
                    'Report Type:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildReportTypeChip('All Reports'),
                        const SizedBox(width: 8),
                        _buildReportTypeChip('Referrals by Doctor'),
                        const SizedBox(width: 8),
                        _buildReportTypeChip('Revenue Report'),
                        const SizedBox(width: 8),
                        _buildReportTypeChip('Patient Report'),
                      ],
                    ),
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
            'Completed Referrals',
            _getCompletedReferralsCount(firebaseService),
            Icons.check_circle,
            [Colors.green[400]!, Colors.green[600]!],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StreamBuilder<Map<String, dynamic>>(
            stream: firebaseService.dashboardStatsStream,
            initialData: firebaseService.dashboardStats,
            builder: (context, snapshot) {
              final stats = snapshot.data ?? {};
              return _buildStatCard(
                'Revenue ($_selectedPeriod)',
                '₹${stats['estimatedRevenue'] ?? 0}',
                Icons.attach_money,
                [Colors.purple[400]!, Colors.purple[600]!],
              );
            },
          ),
        ),
      ],
    );
  }

  String _getCompletedReferralsCount(AdminFirebaseService firebaseService) {
    int completedCount = 0;
    
    // Get all referrals from the report data
    List<dynamic> allReferrals = firebaseService.reportData['allReferrals'] ?? [];
    
    // Debug: Print all referrals and their status
    print('Checking all referrals for completed status:');
    for (var referral in allReferrals) {
      String status = '';
      if (referral.containsKey('status')) {
        status = referral['status'].toString();
      } else if (referral.containsKey('currentStatus')) {
        status = referral['currentStatus'].toString();
      }
      print('Referral ID: ${referral['id']}, Status: $status');
      
      // Check for 'completed' in any case format
      if (status.toLowerCase() == 'completed') {
        completedCount++;
        print('Found completed referral: ${referral['id']}');
      }
    }
    
    // If still no completed referrals found, check for variations
    if (completedCount == 0) {
      for (var referral in allReferrals) {
        String status = '';
        if (referral.containsKey('status')) {
          status = referral['status'].toString();
        } else if (referral.containsKey('currentStatus')) {
          status = referral['currentStatus'].toString();
        }
        
        if (status.toLowerCase().contains('complet')) {
          completedCount++;
          print('Found completed referral (partial match): ${referral['id']}');
        }
      }
    }
    
    // Direct count from Firebase
    if (completedCount == 0) {
      // Use the doctor stats as a fallback
      List<dynamic> referralsByDoctor = firebaseService.reportData['referralsByDoctor'] ?? [];
      for (var doctorStats in referralsByDoctor) {
        if (doctorStats.containsKey('completed')) {
          int docCompleted = (doctorStats['completed'] ?? 0) as int;
          completedCount += docCompleted;
          print('Adding ${docCompleted} completed referrals from doctor: ${doctorStats['doctorName']}');
        }
      }
    }
    
    print('Total completed referrals count: $completedCount');
    return completedCount.toString();
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
    // Get all raw referrals data and referrals by doctor data
    final dataF = firebaseService.reportData;
    final rawReferrals = dataF['allReferrals'] as List<Map<String, dynamic>>? ?? [];
    final allReferrals = dataF['referralsByDoctor'] as List<Map<String, dynamic>>? ?? [];
    final allVisits = dataF['allVisits'] as List<Map<String, dynamic>>? ?? [];

    // --- BEGIN NEW LOGIC ---
    // Map to quickly sum doctor commission per doctor for the selected period
    final Map<String, double> doctorCommissions = {};
    final periodRange = _getPeriodRange(_selectedPeriod);
    final periodStart = periodRange[0];
    final periodEnd = periodRange[1];
    for (final visit in allVisits) {
      // Get doctor name flexibly from possible keys
      final doctorName = visit['doctorName'] ?? visit['refDoctorName'] ??
          visit['doctor'] ?? '';
      // Only sum for visits in the selected period (as per current report filters)
      final visitDate = _parseVisitDate(visit['visitDate']);
      if (doctorName != '' && visitDate != null &&
          !visitDate.isBefore(periodStart) && visitDate.isBefore(periodEnd)) {
        // doctorCommissionAmount is expected to be present from visit logging
        final amt = double.tryParse(
            visit['doctorCommissionAmount']?.toString() ?? '0') ?? 0.0;
        doctorCommissions[doctorName] =
            (doctorCommissions[doctorName] ?? 0.0) + amt;
      }
    }
    // --- END NEW LOGIC ---

    // Create a special list for today's referrals if needed
    List<Map<String, dynamic>> referralsToUse;
    
    if (_selectedPeriod == 'Today') {
      // For Today filter, we need to calculate today's referrals for each doctor
      // Get today's date range
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));
      
      // Group today's referrals by doctor
      Map<String, Map<String, dynamic>> todayReferralsByDoctor = {};
      
      // Process each raw referral
      for (var referral in rawReferrals) {
        final createdAt = _parseVisitDate(referral['createdAt']);
        if (createdAt == null) continue;
        
        // Check if the referral was created today
        if (createdAt.isAfter(todayStart) && createdAt.isBefore(todayEnd)) {
          final doctorName = referral['doctorName']?.toString() ?? 'Unknown';
          // Get status from either 'status' or 'currentStatus' field
          String status = '';
          if (referral.containsKey('status')) {
            status = referral['status'].toString();
          } else if (referral.containsKey('currentStatus')) {
            status = referral['currentStatus'].toString();
          }
          
          // Initialize doctor entry if not exists
          if (!todayReferralsByDoctor.containsKey(doctorName)) {
            todayReferralsByDoctor[doctorName] = {
              'doctorName': doctorName,
              'totalReferrals': 0,
              'completed': 0,
              'pending': 0,
              'createdAt': referral['createdAt'],
            };
          }
          
          // Increment counts
          todayReferralsByDoctor[doctorName]!['totalReferrals'] = 
              (todayReferralsByDoctor[doctorName]!['totalReferrals'] as int) + 1;
              
          // Check for completed status in a more flexible way
          if (status.toLowerCase() == 'completed' || 
              status.toLowerCase().contains('complet') || 
              status.toLowerCase() == 'done') {
            print('Found completed referral for doctor: $doctorName, Status: $status');
            todayReferralsByDoctor[doctorName]!['completed'] = 
                (todayReferralsByDoctor[doctorName]!['completed'] as int) + 1;
          } else {
            todayReferralsByDoctor[doctorName]!['pending'] = 
                (todayReferralsByDoctor[doctorName]!['pending'] as int) + 1;
          }
        }
      }
      
      // Use today's referrals data
      referralsToUse = todayReferralsByDoctor.values.toList();
    } else {
      // For other periods, use the standard filtered data
      // Filter referrals by period using period range
      referralsToUse = allReferrals.where((row) {
        final createdAt = _parseVisitDate(row['createdAt']);
        if (createdAt == null) return true; // Fallback: if missing, include
        final range = _getPeriodRange(_selectedPeriod);
        return !createdAt.isBefore(range[0]) && createdAt.isBefore(range[1]);
      }).toList();
    }
    
    // Apply additional filters
    final referralsFiltered = referralsToUse.where((doctor) {
      // Filter by doctor if selected
      if (_selectedDoctor != null) {
        final doctorName = doctor['doctorName']?.toString() ?? '';
        if (doctorName.isEmpty || doctorName != _selectedDoctor) {
          return false;
        }
      }
      
      // Filter by status if selected
      if (_selectedStatus != null && _selectedStatus != 'All Status') {
        if (_selectedStatus == 'Completed') {
          // Only show doctors with completed referrals
          final completedCount = doctor['completed'] as num? ?? 0;
          if (completedCount <= 0) {
            return false;
          }
        } else if (_selectedStatus == 'Pending') {
          // Only show doctors with pending referrals
          final pendingCount = doctor['pending'] as num? ?? 0;
          if (pendingCount <= 0) {
            return false;
          }
        }
      }
      
      return true;
    }).toList();
    
    // Calculate daily summary totals when Today filter is selected
    int totalReferrals = 0;
    int totalCompleted = 0;
    int totalPending = 0;
    
    if (_selectedPeriod == 'Today') {
      // Count today's referrals for each doctor
      for (var doctor in referralsFiltered) {
        totalReferrals += (doctor['totalReferrals'] as num? ?? 0).toInt();
        totalCompleted += (doctor['completed'] as num? ?? 0).toInt();
        totalPending += (doctor['pending'] as num? ?? 0).toInt();
      }
    }
    
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                // Show daily summary when Today filter is selected
                if (_selectedPeriod == 'Today')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    // The following fixes the assertion error: use only Expanded OR Flexible, not both.
                    // Replacing 'Expanded(child: Flexible(child: ...))' or 'Flexible(child: Expanded(child: ...))' with only direct Text
                    // as only one parent data widget is needed
                    child: Text(
                      'Today: $totalReferrals Total, $totalCompleted Completed, $totalPending Pending',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
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
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 600;
                        final table = DataTable(
                          columns: [
                            const DataColumn(label: Text('Doctor Name')),
                            DataColumn(label: Text(_selectedPeriod == 'Today'
                                ? 'Today\'s Referrals'
                                : 'Total Referrals')),
                            DataColumn(label: Text(_selectedPeriod == 'Today'
                                ? 'Today\'s Completed'
                                : 'Completed')),
                            DataColumn(label: Text(_selectedPeriod == 'Today'
                                ? 'Today\'s Pending'
                                : 'Pending')),
                            // --- NEW COLUMN FOR DOCTOR REVENUE ---
                            const DataColumn(label: Text('Doctor Revenue (₹)')),
                          ],
                          rows: doctorsToDisplay.map((doctor) {
                            final doctorName = doctor['doctorName'] ??
                                'Unknown';
                            // Output revenue for this doctor, formatted to 2 decimal places
                            final revenue = doctorCommissions[doctorName]
                                ?.toStringAsFixed(2) ?? '0.00';
                            return DataRow(cells: [
                              DataCell(Text(doctorName)),
                              DataCell(
                                  Text('${doctor['totalReferrals'] ?? 0}')),
                              DataCell(Text('${doctor['completed'] ?? 0}')),
                              DataCell(Text('${doctor['pending'] ?? 0}')),
                              DataCell(Text('₹$revenue')),
                            ]);
                          }).toList(),
                        );
                        if (isMobile) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: table,
                          );
                        } else {
                          return table;
                        }
                      },
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
    // Type-safe, always get expected structure
    final raw = firebaseService.reportData['patientReport'];
    final List<Map<String, dynamic>> patientReport =
    (raw is List) ? raw.whereType<Map<String, dynamic>>().toList() : [];
    final allVisits = firebaseService.reportData['allVisits'] as List<Map<String, dynamic>>? ?? [];

    // Build patient id to list of all visits
    Map<String, List<Map<String, dynamic>>> visitsByPatientId = {};
    for (final v in allVisits) {
      final pid = v['patientId']?.toString() ?? '';
      if (pid.isEmpty) continue;
      visitsByPatientId.putIfAbsent(pid, () => []).add(v);
    }

    // For each patient: latest visit for financials & date (no date filtering now!)
    Map<String, Map<String, dynamic>?> latestVisitByPatientId = {};
    for (final patient in patientReport) {
      final pid = patient['patientId']?.toString() ?? '';
      final visList = visitsByPatientId[pid] ?? [];
      // Get latest
      Map<String, dynamic>? latest;
      for (final v in visList) {
        final visitDate = _parseVisitDate(v['visitDate']);
        if (visitDate == null) continue;
        if (latest == null || visitDate.isAfter(
            _parseVisitDate(latest['visitDate']) ?? DateTime(1900))) {
          latest = v;
        }
      }
      latestVisitByPatientId[pid] = latest;
    }

    // Robust table: always display all referrals as rows
    final patientsToDisplay = patientReport;
    final hasMorePatients = patientsToDisplay.length > _patientDisplayLimit;
    final visibleRows = hasMorePatients && !_showingAllPatients
        ? patientsToDisplay.take(_patientDisplayLimit).toList()
        : patientsToDisplay;

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
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.refresh, color: Colors.teal[700], size: 20),
                  tooltip: 'Refresh Patient Report',
                  onPressed: () => _refreshPatientReport(firebaseService),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!_patientReportLoaded)
              ...[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 10),
              ],
            if (_patientReportLoaded && visibleRows.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'No patient data available',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else if (_patientReportLoaded)
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 600;
                        final table = DataTable(
                          columns: const [
                            DataColumn(label: Text('Patient Name')),
                            DataColumn(label: Text('Therapist')),
                            DataColumn(label: Text('Doctor')),
                            DataColumn(label: Text('Last Visit')),
                            DataColumn(label: Text('Total Amount')),
                            DataColumn(label: Text('Doctor %')),
                            DataColumn(label: Text('Doctor Commission')),
                            DataColumn(label: Text('Therapist Fees')),
                          ],
                          rows: visibleRows.map((patient) {
                            // Sanitize and handle any type inconsistencies gracefully (robustness)
                            final patientId = patient['patientId']?.toString() ?? '';
                            final latest = latestVisitByPatientId[patientId];

                            String docPerc = latest?['doctorCommissionPercent']
                                ?.toString() ??
                                patient['doctorCommissionPercent']
                                    ?.toString() ?? '-';
                            if (docPerc != '-' && num.tryParse(docPerc) != null)
                              docPerc = '${docPerc}%';

                            String therAmt = latest?['therapistFeeAmount']?.toString() ?? '-';

                            // Show Last Visit as 12h am/pm if today and visitTime present, else as dd-MM-yyyy. Robust parsing
                            String lastVisitDisplay = '-';
                            DateTime? lastVisitDt;
                            String? lastVisitTime;
                            if (latest != null) {
                              final dtField = latest['visitDate'];
                              if (dtField is DateTime)
                                lastVisitDt = dtField;
                              else if (dtField != null &&
                                  dtField.toString().contains('seconds=')) {
                                final match = RegExp(r'seconds=(\d+)')
                                    .firstMatch(dtField.toString());
                                if (match != null) lastVisitDt =
                                    DateTime.fromMillisecondsSinceEpoch(
                                        int.parse(match.group(1)!) * 1000);
                              } else if (dtField != null) {
                                lastVisitDt =
                                    DateTime.tryParse(dtField.toString());
                              }
                              lastVisitTime = latest['visitTime']?.toString();
                            }
                            if (lastVisitDt != null) {
                              final now = DateTime.now();
                              bool isToday = lastVisitDt.year == now.year &&
                                  lastVisitDt.month == now.month &&
                                  lastVisitDt.day == now.day;
                              if (isToday && lastVisitTime != null &&
                                  lastVisitTime != '-' && lastVisitTime
                                  .trim()
                                  .isNotEmpty) {
                                final timeParts = RegExp(r'^(\d{1,2}):(\d{2})')
                                    .firstMatch(lastVisitTime);
                                if (timeParts != null) {
                                  int hour = int.parse(timeParts.group(1)!);
                                  int minute = int.parse(timeParts.group(2)!);
                                  String ampm = hour >= 12 ? 'pm' : 'am';
                                  int hour12 = hour % 12;
                                  if (hour12 == 0) hour12 = 12;
                                  lastVisitDisplay =
                                  '$hour12:${minute.toString().padLeft(
                                      2, '0')} $ampm';
                                } else {
                                  lastVisitDisplay = lastVisitTime;
                                }
                              } else {
                                lastVisitDisplay =
                                '${lastVisitDt.day.toString().padLeft(
                                    2, '0')}-${lastVisitDt.month
                                    .toString()
                                    .padLeft(2, '0')}-${lastVisitDt.year}';
                              }
                            } else {
                              final lastVisitField = patient['lastVisit'];
                              if (lastVisitField != null &&
                                  lastVisitField != '-' && lastVisitField
                                  .toString()
                                  .isNotEmpty) {
                                try {
                                  DateTime? parsed;
                                  if (lastVisitField is DateTime)
                                    parsed = lastVisitField;
                                  else if (lastVisitField.toString().contains(
                                      'seconds=')) {
                                    final match = RegExp(r'seconds=(\d+)')
                                        .firstMatch(lastVisitField.toString());
                                    if (match != null) parsed =
                                        DateTime.fromMillisecondsSinceEpoch(
                                            int.parse(match.group(1)!) * 1000);
                                  } else
                                    parsed = DateTime.tryParse(
                                        lastVisitField.toString());
                                  if (parsed != null) {
                                    lastVisitDisplay =
                                    '${parsed.day.toString().padLeft(
                                        2, '0')}-${parsed.month
                                        .toString()
                                        .padLeft(2, '0')}-${parsed.year}';
                                  } else {
                                    lastVisitDisplay =
                                        lastVisitField.toString();
                                  }
                                } catch (_) {
                                  lastVisitDisplay = lastVisitField.toString();
                                }
                              }
                            }
                            return DataRow(cells: [
                              DataCell(Text(getDisplayPatientName(patient))),
                              DataCell(Text(patient['therapist']?.toString() ??
                                  'Unknown')),
                              DataCell(Text(
                                  patient['doctor']?.toString() ?? 'Unknown')),
                              DataCell(Text(lastVisitDisplay)),
                              DataCell(Text(
                                  patient['totalAmount'] != null &&
                                      patient['totalAmount'] != '-'
                                      ? '₹${patient['totalAmount']}'
                                      : '-' // Show as currency
                              )),
                              DataCell(Text(docPerc)),
                              DataCell(Text(
                                // Show Doctor Commission as totalAmount × doctorCommissionPercent / 100, formatted
                                (() {
                                  final totalAmountRaw = (patient['totalAmount'] ??
                                      '')
                                      .toString()
                                      .replaceAll('₹', '')
                                      .replaceAll(',', '')
                                      .trim();
                                  final percRaw = (patient['doctorCommissionPercent'] ??
                                      '').toString().replaceAll('%', '').trim();
                                  final totalAmount = double.tryParse(
                                      totalAmountRaw);
                                  final percentNumeric = double.tryParse(
                                      percRaw);
                                  if (totalAmount != null &&
                                      percentNumeric != null) {
                                    double commission = totalAmount *
                                        (percentNumeric / 100.0);
                                    return '₹${commission.toStringAsFixed(2)}';
                                  }
                                  return '-';
                                })(),
                              )),
                              DataCell(
                                  (() {
                                    final totalAmountRaw = (patient['totalAmount'] ?? '').toString().replaceAll('₹', '').replaceAll(',', '').trim();
                                    final percRaw = (patient['doctorCommissionPercent'] ?? '').toString().replaceAll('%', '').trim();
                                    final totalAmount = double.tryParse(totalAmountRaw);
                                    final percentNumeric = double.tryParse(percRaw);
                                    if (totalAmount != null && percentNumeric != null) {
                                      double commission = totalAmount * (percentNumeric / 100.0);
                                      double therapistFees = totalAmount - commission;
                                      return Text('₹${therapistFees.toStringAsFixed(2)}');
                                    }
                                    return const Text('-');
                                  })()
                              ),

                            ]);
                          }).toList(),
                        );
                        if (isMobile) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: table,
                          );
                        } else {
                          return table;
                        }
                      },
                    ),
                  ),
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
                          _showingAllPatients
                              ? 'Show Less'
                              : 'View More (${patientsToDisplay.length -
                              _patientDisplayLimit} more)',
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
      // --- BEGIN UPGRADE: Add Doctor Revenue column in export ---
      rows.add([
        'Doctor Name',
        'Total Referrals',
        'Completed',
        'Pending',
        'Doctor Revenue (₹)'
      ]);
      final data = firebaseService.reportData['referralsByDoctor'] as List<
          Map<String, dynamic>>? ?? [];
      final allVisits = firebaseService.reportData['allVisits'] as List<
          Map<String, dynamic>>? ?? [];
      final period = _selectedPeriod;
      final range = _getPeriodRange(period);

      // Recompute commission sum for export, matching the visible logic above
      final Map<String, double> doctorCommissions = {};
      for (final visit in allVisits) {
        final doctorName = visit['doctorName'] ?? visit['refDoctorName'] ??
            visit['doctor'] ?? '';
        final visitDate = _parseVisitDate(visit['visitDate']);
        if (doctorName != '' && visitDate != null &&
            !visitDate.isBefore(range[0]) && visitDate.isBefore(range[1])) {
          final amt = double.tryParse(
              visit['doctorCommissionAmount']?.toString() ?? '0') ?? 0.0;
          doctorCommissions[doctorName] =
              (doctorCommissions[doctorName] ?? 0.0) + amt;
        }
      }

      for (final row in data) {
        // Filter based on createdAt in export too
        final createdAt = _parseVisitDate(row['createdAt']);
        if (createdAt != null &&
            (createdAt.isBefore(range[0]) || !createdAt.isBefore(range[1]))) {
          continue;
        }
        final doctorName = row['doctorName'] ?? '';
        final revenue = doctorCommissions[doctorName]?.toStringAsFixed(2) ??
            '0.00';
        rows.add([
          doctorName,
          '${row['totalReferrals'] ?? 0}',
          '${row['completed'] ?? 0}',
          '${row['pending'] ?? 0}',
          '₹$revenue',
        ]);
      }
      // --- END UPGRADE ---
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
      if (dataV.isNotEmpty) 
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