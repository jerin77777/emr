import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import '../models/models.dart';

class ConsultationRecordsView extends StatefulWidget {
  final User currentUser;
  const ConsultationRecordsView({super.key, required this.currentUser});

  @override
  State<ConsultationRecordsView> createState() => _ConsultationRecordsViewState();
}

class _ConsultationRecordsViewState extends State<ConsultationRecordsView> {
  final _searchController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();

  List<User> _doctors = [];
  int? _selectedDoctorId;
  String? _selectedStatus; // Paid, Pending, Unbilled

  List<Map<String, dynamic>> _records = [];
  bool _isLoading = false;

  // Pagination
  int _currentPage = 0;
  final int _pageSize = 10;
  int _totalRecords = 0;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
    _fetchRecords();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctors() async {
    try {
      final allUsers = await DatabaseHelper.instance.getAllUsers();
      setState(() {
        _doctors = allUsers.where((u) => u.role.toLowerCase() == 'doctor').toList();
      });
    } catch (_) {}
  }

  Future<void> _fetchRecords() async {
    setState(() => _isLoading = true);
    try {
      final query = _searchController.text.trim();
      final start = _startDateController.text.trim();
      final end = _endDateController.text.trim();

      final count = await DatabaseHelper.instance.countConsultations(
        query: query,
        startDate: start.isNotEmpty ? start : null,
        endDate: end.isNotEmpty ? end : null,
        doctorId: _selectedDoctorId,
        status: _selectedStatus,
      );

      final results = await DatabaseHelper.instance.searchConsultations(
        query: query,
        startDate: start.isNotEmpty ? start : null,
        endDate: end.isNotEmpty ? end : null,
        doctorId: _selectedDoctorId,
        status: _selectedStatus,
        limit: _pageSize,
        offset: _currentPage * _pageSize,
      );

      setState(() {
        _records = results;
        _totalRecords = count;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching records: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _clearFilters() {
    _searchController.clear();
    _startDateController.clear();
    _endDateController.clear();
    setState(() {
      _selectedDoctorId = null;
      _selectedStatus = null;
      _currentPage = 0;
    });
    _fetchRecords();
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.teal.shade700,
              onPrimary: Colors.white,
              onSurface: Colors.teal.shade900,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        // Format as YYYY-MM-DD
        controller.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
        _currentPage = 0;
      });
      _fetchRecords();
    }
  }

  int get _totalPages => (_totalRecords / _pageSize).ceil();

  void _showConsultationDetails(Map<String, dynamic> record) {
    showDialog(
      context: context,
      builder: (context) {
        final vitalsList = <String>[];
        if (record['vitals_bp']?.isNotEmpty == true) vitalsList.add('BP: ${record['vitals_bp']}');
        if (record['vitals_pulse']?.isNotEmpty == true) vitalsList.add('Pulse: ${record['vitals_pulse']}');
        if (record['vitals_temp']?.isNotEmpty == true) vitalsList.add('Temp: ${record['vitals_temp']}');
        if (record['vitals_saturation']?.isNotEmpty == true) vitalsList.add('SPO2: ${record['vitals_saturation']}');

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Consultation Visit Details', style: TextStyle(color: Colors.teal.shade900, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meta Info Row
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Visit ID: ${record['visit_uuid'].toString().substring(0, 8)}...', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('Date: ${record['visit_date'] ?? "N/A"}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Patient Info
                  _detailField('Patient Name', record['patient_name'] ?? 'N/A'),
                  _detailField('Patient Code', record['patient_code'] ?? 'N/A'),
                  _detailField('Patient Mobile', record['patient_mobile'] ?? 'N/A'),
                  _detailField('Consulting Doctor', record['doctor_name'] ?? 'N/A'),
                  const Divider(height: 24),

                  // Clinical Details
                  if (record['chief_complaint']?.isNotEmpty == true)
                    _detailField('Chief Complaint', record['chief_complaint']),
                  if (record['history']?.isNotEmpty == true)
                    _detailField('History', record['history']),
                  if (vitalsList.isNotEmpty)
                    _detailField('Vitals Signs', vitalsList.join(' | ')),
                  if (record['diagnosis']?.isNotEmpty == true)
                    _detailField('Diagnosis', "${record['diagnosis']}${record['diagnosis_code'] != null ? ' (ICD-10: ${record['diagnosis_code']})' : ''}"),
                  if (record['advice']?.isNotEmpty == true)
                    _detailField('Advice & Prescriptions', record['advice']),
                  if (record['referral_to']?.isNotEmpty == true)
                    _detailField('Referral To', record['referral_to']),
                  if (record['followup_date']?.isNotEmpty == true)
                    _detailField('Follow-up Date', record['followup_date']),
                  const Divider(height: 24),
                  
                  // Billing status
                  _detailField('Billing Invoice Status', record['bill_status'] ?? 'Unbilled'),
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () => _printConsultation(record),
              icon: const Icon(Icons.print),
              label: const Text('Print / Export'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.teal.shade900),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
              child: const Text('Close'),
            )
          ],
        );
      },
    );
  }

  Widget _detailField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: CrossAxisAlignment.start == CrossAxisAlignment.start
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 6),
              ],
            )
          : const SizedBox.shrink(),
    );
  }

  void _printConsultation(Map<String, dynamic> record) {
    final vitalsList = <String>[];
    if (record['vitals_bp']?.isNotEmpty == true) vitalsList.add('BP: ${record['vitals_bp']}');
    if (record['vitals_pulse']?.isNotEmpty == true) vitalsList.add('Pulse: ${record['vitals_pulse']}');
    if (record['vitals_temp']?.isNotEmpty == true) vitalsList.add('Temp: ${record['vitals_temp']}');
    if (record['vitals_saturation']?.isNotEmpty == true) vitalsList.add('SPO2: ${record['vitals_saturation']}');

    final printContent = '''
======================================================
                  CLINIC VISIT RECORD
======================================================
Patient Name  : ${record['patient_name']}
Patient Code  : ${record['patient_code']}
Mobile Number : ${record['patient_mobile']}
Visit Date    : ${record['visit_date'] ?? "N/A"}
Visit UUID    : ${record['visit_uuid']}
Consultant    : ${record['doctor_name'] ?? "N/A"}
------------------------------------------------------
CHIEF COMPLAINT:
${record['chief_complaint'] ?? "None documented"}

HISTORY:
${record['history'] ?? "None documented"}

VITALS:
${vitalsList.isEmpty ? "None documented" : vitalsList.join(' | ')}

DIAGNOSIS:
${record['diagnosis'] ?? "None documented"} ${record['diagnosis_code'] != null ? '(${record['diagnosis_code']})' : ''}

ADVICE & PRESCRIPTION:
${record['advice'] ?? "None documented"}

FOLLOW-UP DATE:
${record['followup_date'] ?? "None"}
------------------------------------------------------
Generated via Clinic EMR - Cloud Synced Backup
======================================================
''';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Consultation Print Preview'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This document is formatted and ready for printing:'),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                width: 500,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    printContent,
                    style: const TextStyle(fontFamily: 'Courier', fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: printContent));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Consultation text copied to clipboard!')),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy Text'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('PDF layout generated! Sending job to printer...'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
              icon: const Icon(Icons.print),
              label: const Text('Simulate Print'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter controls card
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) {
                              setState(() => _currentPage = 0);
                              _fetchRecords();
                            },
                            decoration: InputDecoration(
                              hintText: 'Search by patient name, ID, phone, visit UUID, or diagnosis...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: _clearFilters,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade200,
                            foregroundColor: Colors.teal.shade900,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          icon: const Icon(Icons.clear_all),
                          label: const Text('Reset'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        // Start Date
                        Expanded(
                          child: TextFormField(
                            controller: _startDateController,
                            readOnly: true,
                            onTap: () => _selectDate(context, _startDateController),
                            decoration: InputDecoration(
                              labelText: 'Start Date',
                              suffixIcon: const Icon(Icons.calendar_today, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // End Date
                        Expanded(
                          child: TextFormField(
                            controller: _endDateController,
                            readOnly: true,
                            onTap: () => _selectDate(context, _endDateController),
                            decoration: InputDecoration(
                              labelText: 'End Date',
                              suffixIcon: const Icon(Icons.calendar_today, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Doctor Dropdown
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _selectedDoctorId,
                            decoration: InputDecoration(
                              labelText: 'Doctor',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('All Doctors')),
                              ..._doctors.map((doc) => DropdownMenuItem(
                                    value: doc.id,
                                    child: Text(doc.fullName),
                                  )),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedDoctorId = val;
                                _currentPage = 0;
                              });
                              _fetchRecords();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Billing Status Dropdown
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedStatus,
                            decoration: InputDecoration(
                              labelText: 'Billing Status',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: const [
                              DropdownMenuItem(value: null, child: Text('All Billing States')),
                              DropdownMenuItem(value: 'Paid', child: Text('Paid')),
                              DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                              DropdownMenuItem(value: 'Unbilled', child: Text('Unbilled')),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedStatus = val;
                                _currentPage = 0;
                              });
                              _fetchRecords();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Records Table Card
            Expanded(
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Clinical Consultations',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.teal.shade900,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            '$_totalRecords records found',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Search Results
                      Expanded(
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _records.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.history_edu_outlined, size: 64, color: Colors.grey.shade400),
                                        const SizedBox(height: 12),
                                        Text(
                                          'No consultation records found matching your filters.',
                                          style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                                        ),
                                      ],
                                    ),
                                  )
                                : SingleChildScrollView(
                                    scrollDirection: Axis.vertical,
                                    child: Table(
                                      columnWidths: const {
                                        0: FlexColumnWidth(2), // Date
                                        1: FlexColumnWidth(2), // Patient Code
                                        2: FlexColumnWidth(3), // Patient Name
                                        3: FlexColumnWidth(3), // Doctor
                                        4: FlexColumnWidth(4), // Diagnosis
                                        5: FlexColumnWidth(2), // Billing status
                                        6: FlexColumnWidth(2), // Actions
                                      },
                                      border: TableBorder(
                                        horizontalInside: BorderSide(color: Colors.grey.shade200, width: 1),
                                      ),
                                      children: [
                                        // Header Row
                                        TableRow(
                                          decoration: BoxDecoration(color: Colors.teal.shade50),
                                          children: const [
                                            Padding(padding: EdgeInsets.all(12), child: Text('Visit Date', style: TextStyle(fontWeight: FontWeight.bold))),
                                            Padding(padding: EdgeInsets.all(12), child: Text('ID Code', style: TextStyle(fontWeight: FontWeight.bold))),
                                            Padding(padding: EdgeInsets.all(12), child: Text('Patient Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                            Padding(padding: EdgeInsets.all(12), child: Text('Doctor', style: TextStyle(fontWeight: FontWeight.bold))),
                                            Padding(padding: EdgeInsets.all(12), child: Text('Diagnosis', style: TextStyle(fontWeight: FontWeight.bold))),
                                            Padding(padding: EdgeInsets.all(12), child: Text('Billing', style: TextStyle(fontWeight: FontWeight.bold))),
                                            Padding(padding: EdgeInsets.all(12), child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                                          ],
                                        ),
                                        // Data Rows
                                        ..._records.map((rec) {
                                          final billStatus = rec['bill_status'] ?? 'Unbilled';
                                          return TableRow(
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                                                child: Text(rec['visit_date'] ?? 'N/A'),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                                                child: Text(rec['patient_code'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold)),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                                                child: Text(rec['patient_name'] ?? 'N/A'),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                                                child: Text(rec['doctor_name'] ?? 'N/A'),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                                                child: Text(
                                                  rec['diagnosis'] ?? 'No Diagnosis',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                                                child: Container(
                                                  alignment: Alignment.center,
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: billStatus == 'Paid'
                                                        ? Colors.green.shade50
                                                        : billStatus == 'Pending'
                                                            ? Colors.amber.shade50
                                                            : Colors.grey.shade100,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    billStatus,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: billStatus == 'Paid'
                                                          ? Colors.green.shade900
                                                          : billStatus == 'Pending'
                                                              ? Colors.amber.shade900
                                                              : Colors.grey.shade800,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                                child: Row(
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(Icons.visibility, color: Colors.teal),
                                                      tooltip: 'View Details',
                                                      onPressed: () => _showConsultationDetails(rec),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.print, color: Colors.grey),
                                                      tooltip: 'Print',
                                                      onPressed: () => _printConsultation(rec),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                      ),
                      
                      // Pagination Controller
                      if (_totalPages > 1) ...[
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Showing ${(_currentPage * _pageSize) + 1} to ${((_currentPage + 1) * _pageSize).clamp(0, _totalRecords)} of $_totalRecords entries',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.chevron_left),
                                  onPressed: _currentPage > 0
                                      ? () {
                                          setState(() => _currentPage--);
                                          _fetchRecords();
                                        }
                                      : null,
                                ),
                                Text(
                                  'Page ${_currentPage + 1} of $_totalPages',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right),
                                  onPressed: _currentPage < _totalPages - 1
                                      ? () {
                                          setState(() => _currentPage++);
                                          _fetchRecords();
                                        }
                                      : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
