import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/models.dart';
import 'patient_registration_dialog.dart';
import 'patient_detail_view.dart';
import 'clinical_consultation_view.dart';
import 'billing_view.dart';
import '../main.dart';

class PatientManagementView extends StatefulWidget {
  final User currentUser;

  const PatientManagementView({super.key, required this.currentUser});

  @override
  State<PatientManagementView> createState() => _PatientManagementViewState();
}

class _PatientManagementViewState extends State<PatientManagementView> {
  final _searchController = TextEditingController();
  late Future<List<Patient>> _patientsFuture;
  String _selectedGenderFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadPatients();
    DatabaseHelper.changeNotifier.addListener(_loadPatients);
  }

  void _loadPatients() {
    setState(() {
      _patientsFuture = DatabaseHelper.instance.searchPatients(
        _searchController.text.trim(),
      );
    });
  }

  @override
  void dispose() {
    DatabaseHelper.changeNotifier.removeListener(_loadPatients);
    _searchController.dispose();
    super.dispose();
  }

  void _showRegistrationDialog([Patient? existingPatient]) {
    showDialog(
      context: context,
      builder: (context) => PatientRegistrationDialog(
        existingPatient: existingPatient,
        onSaved: _loadPatients,
      ),
    );
  }

  void _openPatientDetail(Patient patient) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientDetailView(
          patient: patient,
          currentUser: widget.currentUser,
        ),
      ),
    ).then((_) => _loadPatients());
  }

  Future<void> _deletePatient(Patient p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Text('Delete Patient Record'),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete "${p.fullName}" (ID: ${p.patientCode})?\n\nThis will permanently remove the patient and all associated consultations, invoices, and medical records.',
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
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirm == true && p.id != null) {
      try {
        await DatabaseHelper.instance.deletePatient(p.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Patient "${p.fullName}" and all associated records deleted.'),
              backgroundColor: Colors.green,
            ),
          );
        }
        _loadPatients();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting patient: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _startConsultation(Patient patient) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClinicalConsultationView(
          patient: patient,
          currentUser: widget.currentUser,
        ),
      ),
    ).then((_) => _loadPatients());
  }

  void _generateBill(Patient patient) {
    final dashboardState = context.findAncestorStateOfType<DashboardShellState>();
    if (dashboardState != null) {
      dashboardState.navigateToSection('billing', patient: patient);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              BillingView(patient: patient, currentUser: widget.currentUser),
        ),
      ).then((_) => _loadPatients());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Search Bar & Actions
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => _loadPatients(),
                    decoration: InputDecoration(
                      hintText:
                          'Search patients by Name, Patient ID, or Mobile...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _loadPatients();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _showRegistrationDialog(),
                  icon: const Icon(Icons.person_add),
                  label: const Text(
                    'REGISTER NEW PATIENT',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Gender Filters
            Row(
              children: [
                const Text(
                  'Filter: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('All Patients'),
                  selected: _selectedGenderFilter == 'All',
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedGenderFilter = 'All');
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Male'),
                  selected: _selectedGenderFilter == 'Male',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedGenderFilter = 'Male');
                    }
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Female'),
                  selected: _selectedGenderFilter == 'Female',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedGenderFilter = 'Female');
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Patient Directory List
            Expanded(
              child: FutureBuilder<List<Patient>>(
                future: _patientsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error loading patients: ${snapshot.error}'),
                    );
                  }

                  var patients = snapshot.data ?? [];
                  if (_selectedGenderFilter != 'All') {
                    patients = patients
                        .where(
                          (p) =>
                              p.gender.toLowerCase() ==
                              _selectedGenderFilter.toLowerCase(),
                        )
                        .toList();
                  }

                  if (patients.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_search_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchController.text.isEmpty
                                ? 'No registered patients in the system database.'
                                : 'No patients matching "${_searchController.text}".',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal.shade700,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => _showRegistrationDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('Register Patient Now'),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: patients.length,
                    itemBuilder: (context, index) {
                      final p = patients[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _openPatientDetail(p),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: p.gender == 'Male'
                                      ? Colors.blue.shade100
                                      : Colors.pink.shade100,
                                  child: Text(
                                    p.fullName.isNotEmpty
                                        ? p.fullName[0].toUpperCase()
                                        : 'P',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal.shade900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            p.fullName,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.teal.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                color: Colors.teal.shade200,
                                              ),
                                            ),
                                            child: Text(
                                              p.patientCode,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: Colors.teal.shade900,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${p.gender} | ${p.age != null ? "${p.age} yrs" : "DOB: ${p.dateOfBirth}"} | Phone: ${p.mobileNumber}${p.referralDoctor != null ? " | Ref: ${p.referralDoctor}" : ""}',
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal.shade700,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () => _startConsultation(p),
                                      icon: const Icon(
                                        Icons.medical_services,
                                        size: 18,
                                      ),
                                      label: const Text('New Visit'),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.receipt_long,
                                        color: Colors.teal,
                                      ),
                                      tooltip: 'Generate Bill',
                                      onPressed: () => _generateBill(p),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        color: Colors.grey,
                                      ),
                                      tooltip: 'Edit Patient Demographics',
                                      onPressed: () =>
                                          _showRegistrationDialog(p),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline,
                                        color: Colors.red.shade400,
                                      ),
                                      tooltip: 'Delete Patient Record',
                                      onPressed: () => _deletePatient(p),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
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
