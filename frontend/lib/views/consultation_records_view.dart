import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/models.dart';
import '../utils/date_formatter.dart';
import '../widgets/common_widgets.dart';
import 'clinical_consultation_view.dart';

class ConsultationRecordsView extends StatefulWidget {
  final User currentUser;
  const ConsultationRecordsView({super.key, required this.currentUser});

  @override
  State<ConsultationRecordsView> createState() =>
      _ConsultationRecordsViewState();
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
        _doctors = allUsers
            .where((u) => u.role.toLowerCase() == 'doctor')
            .toList();
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
          SnackBar(
            content: Text('Error searching records: $e'),
            backgroundColor: Colors.red,
          ),
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

  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
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
        controller.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
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
        final formattedVitals = VitalsFormatter.formatAll(
          bp: record['vitals_bp'],
          pulse: record['vitals_pulse'],
          temp: record['vitals_temp'],
          saturation: record['vitals_saturation'],
          includePlaceholders: true,
        );

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Consultation Visit Details',
                style: TextStyle(
                  color: Colors.teal.shade900,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Simplified Patient & Doctor Header card with Date on the right
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record['patient_name'] ?? 'N/A',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Patient ID: ${record['patient_code'] ?? 'N/A'}',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Doctor: ${record['doctor_name'] ?? 'N/A'}',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              DateFormatter.formatDate(record['visit_date']),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.teal.shade900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  // Clinical Details
                  if (record['chief_complaint']?.isNotEmpty == true)
                    _detailField('Chief Complaint', record['chief_complaint']),
                  if (record['history']?.isNotEmpty == true)
                    _detailField('History', record['history']),
                  _detailField('Vital Signs', formattedVitals),
                  if (record['diagnosis']?.isNotEmpty == true)
                    _detailField('Diagnosis', record['diagnosis']),
                  if (record['advice']?.isNotEmpty == true)
                    _detailField('Advice & Prescriptions', record['advice']),
                  if (record['referral_to']?.isNotEmpty == true)
                    _detailField('Referral To', record['referral_to']),
                  if (record['followup_date']?.isNotEmpty == true)
                    _detailField(
                      'Follow-up Date',
                      DateFormatter.formatDate(record['followup_date']),
                    ),
                  const Divider(height: 24),

                  // Billing status
                  _detailField(
                    'Billing Invoice Status',
                    record['bill_status'] ?? 'Unbilled',
                  ),
                  const SizedBox(height: 4),
                  _detailField(
                    'Editable Status',
                    DateFormatter.getEditStatusText(
                      record['visit_date'],
                      record['created_at'],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () => _printConsultation(record),
              icon: const Icon(Icons.print),
              label: const Text('Print / Export'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.teal.shade900,
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteConsultation(Map<String, dynamic> record) async {
    final visitId = (record['id'] as num?)?.toInt();
    final visitNumber = record['visit_number'] ?? '';
    final patientName = record['patient_name'] ?? 'Patient';
    if (visitId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Text('Delete Consultation Visit'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete Consultation Visit #$visitNumber for "$patientName"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Visit'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await DatabaseHelper.instance.deletePatientVisit(visitId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Consultation Visit #$visitNumber deleted successfully.',
              ),
              backgroundColor: Colors.green,
            ),
          );
          _fetchRecords();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting consultation: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _openEditConsultation(Map<String, dynamic> record) async {
    try {
      final visitId = (record['id'] as num?)?.toInt();
      final patientId = (record['patient_id'] as num?)?.toInt();
      if (visitId == null || patientId == null) return;

      final patient = await DatabaseHelper.instance.getPatientById(patientId);
      final visit = await DatabaseHelper.instance.getPatientVisitById(visitId);

      if (patient == null || visit == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not load consultation record to edit.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (!mounted) return;
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => ClinicalConsultationView(
            patient: patient,
            currentUser: widget.currentUser,
            existingVisit: visit,
          ),
        ),
      );

      if (result == true || mounted) {
        _fetchRecords();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening editor: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _detailField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.teal.shade900,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  void _printConsultation(Map<String, dynamic> record) {
    ConsultationPrintPreviewDialog.show(
      context,
      dialog: ConsultationPrintPreviewDialog.fromMap(record: record),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
                              hintText:
                                  'Search by patient name, ID, phone, visit UUID, or diagnosis...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: _clearFilters,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade200,
                            foregroundColor: Colors.teal.shade900,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
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
                            onTap: () =>
                                _selectDate(context, _startDateController),
                            decoration: InputDecoration(
                              labelText: 'Start Date',
                              suffixIcon: const Icon(
                                Icons.calendar_today,
                                size: 18,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // End Date
                        Expanded(
                          child: TextFormField(
                            controller: _endDateController,
                            readOnly: true,
                            onTap: () =>
                                _selectDate(context, _endDateController),
                            decoration: InputDecoration(
                              labelText: 'End Date',
                              suffixIcon: const Icon(
                                Icons.calendar_today,
                                size: 18,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
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
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('All Doctors'),
                              ),
                              ..._doctors.map(
                                (doc) => DropdownMenuItem(
                                  value: doc.id,
                                  child: Text(doc.fullName),
                                ),
                              ),
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
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: null,
                                child: Text('All Billing States'),
                              ),
                              DropdownMenuItem(
                                value: 'Paid',
                                child: Text('Paid'),
                              ),
                              DropdownMenuItem(
                                value: 'Pending',
                                child: Text('Pending'),
                              ),
                              DropdownMenuItem(
                                value: 'Unbilled',
                                child: Text('Unbilled'),
                              ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
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
                                    Icon(
                                      Icons.history_edu_outlined,
                                      size: 64,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No consultation records found matching your filters.',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 15,
                                      ),
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
                                    horizontalInside: BorderSide(
                                      color: Colors.grey.shade200,
                                      width: 1,
                                    ),
                                  ),
                                  children: [
                                    // Header Row
                                    TableRow(
                                      decoration: BoxDecoration(
                                        color: Colors.teal.shade50,
                                      ),
                                      children: const [
                                        Padding(
                                          padding: EdgeInsets.all(12),
                                          child: Text(
                                            'Visit Date',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.all(12),
                                          child: Text(
                                            'Patient ID',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.all(12),
                                          child: Text(
                                            'Patient Name',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.all(12),
                                          child: Text(
                                            'Doctor',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.all(12),
                                          child: Text(
                                            'Diagnosis',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.all(12),
                                          child: Text(
                                            'Billing',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.all(12),
                                          child: Text(
                                            'Actions',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Data Rows
                                    ..._records.map((rec) {
                                      final billStatus =
                                          rec['bill_status'] ?? 'Unbilled';
                                      return TableRow(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8.0,
                                              vertical: 12.0,
                                            ),
                                            child: Text(
                                              DateFormatter.formatDate(
                                                rec['visit_date'],
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8.0,
                                              vertical: 12.0,
                                            ),
                                            child: Text(
                                              rec['patient_code'] ?? 'N/A',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8.0,
                                              vertical: 12.0,
                                            ),
                                            child: Text(
                                              rec['patient_name'] ?? 'N/A',
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8.0,
                                              vertical: 12.0,
                                            ),
                                            child: Text(
                                              rec['doctor_name'] ?? 'N/A',
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8.0,
                                              vertical: 12.0,
                                            ),
                                            child: Text(
                                              rec['diagnosis'] ??
                                                  'No Diagnosis',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8.0,
                                              vertical: 8.0,
                                            ),
                                            child: Container(
                                              alignment: Alignment.center,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: billStatus == 'Paid'
                                                    ? Colors.green.shade50
                                                    : billStatus == 'Pending'
                                                    ? Colors.amber.shade50
                                                    : Colors.grey.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(4),
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
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 2.0,
                                              vertical: 2.0,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.visibility,
                                                    color: Colors.teal,
                                                    size: 18,
                                                  ),
                                                  tooltip: 'View Details',
                                                  splashRadius: 14,
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints(
                                                        minWidth: 24,
                                                        minHeight: 24,
                                                      ),
                                                  onPressed: () =>
                                                      _showConsultationDetails(
                                                        rec,
                                                      ),
                                                ),
                                                const SizedBox(width: 4),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.print,
                                                    color: Colors.grey,
                                                    size: 18,
                                                  ),
                                                  tooltip: 'Print',
                                                  splashRadius: 14,
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints(
                                                        minWidth: 24,
                                                        minHeight: 24,
                                                      ),
                                                  onPressed: () =>
                                                      _printConsultation(rec),
                                                ),
                                                const SizedBox(width: 4),
                                                Builder(
                                                  builder: (context) {
                                                    final isEditable =
                                                        DateFormatter.isVisitEditable(
                                                          rec['visit_date'],
                                                          rec['created_at'],
                                                        );
                                                    final editStatus =
                                                        DateFormatter.getEditStatusText(
                                                          rec['visit_date'],
                                                          rec['created_at'],
                                                        );
                                                    return PopupMenuButton<
                                                      String
                                                    >(
                                                      tooltip: 'More Actions',
                                                      padding: EdgeInsets.zero,
                                                      constraints:
                                                          const BoxConstraints(
                                                            minWidth: 24,
                                                            minHeight: 24,
                                                          ),
                                                      child: const Padding(
                                                        padding:
                                                            EdgeInsets.symmetric(
                                                              horizontal: 2,
                                                              vertical: 2,
                                                            ),
                                                        child: Icon(
                                                          Icons.more_vert,
                                                          color: Colors.black87,
                                                          size: 18,
                                                        ),
                                                      ),
                                                      onSelected: (value) {
                                                        if (value == 'edit') {
                                                          _openEditConsultation(
                                                            rec,
                                                          );
                                                        } else if (value ==
                                                            'delete') {
                                                          _confirmDeleteConsultation(
                                                            rec,
                                                          );
                                                        }
                                                      },
                                                      itemBuilder: (ctx) => [
                                                        PopupMenuItem(
                                                          value: 'edit',
                                                          enabled: isEditable,
                                                          child: Row(
                                                            children: [
                                                              Icon(
                                                                Icons
                                                                    .edit_outlined,
                                                                size: 18,
                                                                color:
                                                                    isEditable
                                                                    ? Colors
                                                                          .teal
                                                                          .shade700
                                                                    : Colors
                                                                          .grey,
                                                              ),
                                                              const SizedBox(
                                                                width: 8,
                                                              ),
                                                              Expanded(
                                                                child: Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    Text(
                                                                      'Edit Consultation',
                                                                      style: TextStyle(
                                                                        color:
                                                                            isEditable
                                                                            ? Colors.black87
                                                                            : Colors.grey,
                                                                        fontWeight:
                                                                            FontWeight.w500,
                                                                      ),
                                                                    ),
                                                                    Text(
                                                                      editStatus,
                                                                      style: TextStyle(
                                                                        fontSize:
                                                                            10,
                                                                        color: Colors
                                                                            .grey
                                                                            .shade600,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        const PopupMenuDivider(),
                                                        const PopupMenuItem(
                                                          value: 'delete',
                                                          child: Row(
                                                            children: [
                                                              Icon(
                                                                Icons
                                                                    .delete_outline,
                                                                size: 18,
                                                                color:
                                                                    Colors.red,
                                                              ),
                                                              SizedBox(
                                                                width: 8,
                                                              ),
                                                              Text(
                                                                'Delete Visit',
                                                                style: TextStyle(
                                                                  color: Colors
                                                                      .red,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  },
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
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
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
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
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
