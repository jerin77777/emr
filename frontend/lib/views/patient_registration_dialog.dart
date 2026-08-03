import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/models.dart';

class PatientRegistrationDialog extends StatefulWidget {
  final Patient? existingPatient;
  final VoidCallback onSaved;

  const PatientRegistrationDialog({
    super.key,
    this.existingPatient,
    required this.onSaved,
  });

  @override
  State<PatientRegistrationDialog> createState() => _PatientRegistrationDialogState();
}

class _PatientRegistrationDialogState extends State<PatientRegistrationDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _fullNameController;
  late TextEditingController _dobController;
  late TextEditingController _ageController;
  late TextEditingController _occupationController;
  late TextEditingController _mobileController;
  late TextEditingController _addressController;
  late TextEditingController _emailController;
  late TextEditingController _emergencyContactController;
  late TextEditingController _referralDoctorController;

  String _gender = 'Male';
  bool _isLoading = false;
  String _generatedPatientCode = '';

  @override
  void initState() {
    super.initState();
    final p = widget.existingPatient;
    _fullNameController = TextEditingController(text: p?.fullName ?? '');
    _dobController = TextEditingController(text: p?.dateOfBirth ?? '');
    _ageController = TextEditingController(text: p?.age != null ? p!.age.toString() : '');
    _occupationController = TextEditingController(text: p?.occupation ?? '');
    _mobileController = TextEditingController(text: p?.mobileNumber ?? '');
    _addressController = TextEditingController(text: p?.address ?? '');
    _emailController = TextEditingController(text: p?.email ?? '');
    _emergencyContactController = TextEditingController(text: p?.emergencyContact ?? '');
    _referralDoctorController = TextEditingController(text: p?.referralDoctor ?? '');
    if (p?.gender != null) {
      _gender = p!.gender;
    }

    if (p == null) {
      _loadNextPatientCode();
    } else {
      _generatedPatientCode = p.patientCode;
    }
  }

  Future<void> _loadNextPatientCode() async {
    final code = await DatabaseHelper.instance.generateNextPatientCode();
    if (mounted) {
      setState(() {
        _generatedPatientCode = code;
      });
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _dobController.dispose();
    _ageController.dispose();
    _occupationController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _emergencyContactController.dispose();
    _referralDoctorController.dispose();
    super.dispose();
  }

  Future<void> _selectDateOfBirth() async {
    final now = DateTime.now();
    final initialDate = widget.existingPatient?.dateOfBirth != null
        ? DateTime.tryParse(widget.existingPatient!.dateOfBirth) ?? DateTime(1990, 1, 1)
        : DateTime(1990, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (picked != null) {
      final formatted = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      final age = now.year - picked.year - ((now.month < picked.month || (now.month == picked.month && now.day < picked.day)) ? 1 : 0);
      setState(() {
        _dobController.text = formatted;
        _ageController.text = age.toString();
      });
    }
  }

  Future<void> _savePatient() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final uuid = widget.existingPatient?.patientUuid ?? 'pat-${DateTime.now().millisecondsSinceEpoch}';
      final ageNum = int.tryParse(_ageController.text.trim());

      final patient = Patient(
        id: widget.existingPatient?.id,
        patientUuid: uuid,
        patientCode: _generatedPatientCode,
        fullName: _fullNameController.text.trim(),
        dateOfBirth: _dobController.text.trim(),
        age: ageNum,
        gender: _gender,
        occupation: _occupationController.text.trim().isEmpty ? null : _occupationController.text.trim(),
        mobileNumber: _mobileController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        emergencyContact: _emergencyContactController.text.trim().isEmpty ? null : _emergencyContactController.text.trim(),
        referralDoctor: _referralDoctorController.text.trim().isEmpty ? null : _referralDoctorController.text.trim(),
        syncStatus: 'pending',
      );

      if (widget.existingPatient == null) {
        await DatabaseHelper.instance.insertPatient(patient);
      } else {
        await DatabaseHelper.instance.updatePatient(patient);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.existingPatient == null ? 'Patient registered successfully!' : 'Patient updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving patient: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingPatient != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 680,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.teal.shade100,
                    child: Icon(Icons.person_add, color: Colors.teal.shade800),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEdit ? 'Edit Patient Information' : 'Register New Patient',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Chip(
                    label: Text(_generatedPatientCode, style: const TextStyle(fontWeight: FontWeight.bold)),
                    backgroundColor: Colors.teal.shade50,
                  ),
                ],
              ),
              const Divider(height: 24),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _fullNameController,
                              decoration: const InputDecoration(
                                labelText: 'Full Name *',
                                prefixIcon: Icon(Icons.badge),
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Full Name is required' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: DropdownButtonFormField<String>(
                              initialValue: _gender,
                              decoration: const InputDecoration(
                                labelText: 'Gender *',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Male', child: Text('Male')),
                                DropdownMenuItem(value: 'Female', child: Text('Female')),
                                DropdownMenuItem(value: 'Other', child: Text('Other')),
                              ],
                              onChanged: (v) {
                                if (v != null) setState(() => _gender = v);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _dobController,
                              readOnly: true,
                              onTap: _selectDateOfBirth,
                              decoration: const InputDecoration(
                                labelText: 'Date of Birth *',
                                prefixIcon: Icon(Icons.calendar_today),
                                suffixIcon: Icon(Icons.arrow_drop_down),
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Select Date of Birth' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _ageController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Age (Years)',
                                prefixIcon: Icon(Icons.numbers),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _mobileController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Mobile Number *',
                                prefixIcon: Icon(Icons.phone),
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Mobile number required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _occupationController,
                              decoration: const InputDecoration(
                                labelText: 'Occupation',
                                prefixIcon: Icon(Icons.work),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email Address (Optional)',
                                prefixIcon: Icon(Icons.email),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _addressController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Full Address',
                          prefixIcon: Icon(Icons.home),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _emergencyContactController,
                              decoration: const InputDecoration(
                                labelText: 'Emergency Contact (Name / Phone)',
                                prefixIcon: Icon(Icons.contact_phone),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _referralDoctorController,
                              decoration: const InputDecoration(
                                labelText: 'Referral Doctor / Source',
                                prefixIcon: Icon(Icons.medical_information),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: _isLoading ? null : _savePatient,
                    icon: _isLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save),
                    label: Text(isEdit ? 'Update Patient' : 'Register Patient'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
