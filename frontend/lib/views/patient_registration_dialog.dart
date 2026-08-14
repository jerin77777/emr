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
  late TextEditingController _identityNumberController;

  String _gender = 'Male';
  String _identityType = 'Aadhaar';
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
    
    // Parse proof of identity
    if (p?.proofOfIdentity != null && p!.proofOfIdentity!.contains('|')) {
      _identityType = p.identityType ?? 'Aadhaar';
      _identityNumberController = TextEditingController(text: p.identityNumber ?? '');
    } else {
      _identityType = 'Aadhaar';
      _identityNumberController = TextEditingController();
    }
    
    if (p?.gender != null) {
      _gender = p!.gender;
    }

    if (p == null) {
      _loadNextPatientCode();
    } else {
      _generatedPatientCode = p.patientCode;
    }

    // Auto-calculate age if DOB exists but age is empty
    if (_dobController.text.isNotEmpty && _ageController.text.isEmpty) {
      final parsed = DateTime.tryParse(_dobController.text);
      if (parsed != null) {
        final now = DateTime.now();
        int age = now.year - parsed.year;
        if (now.month < parsed.month || (now.month == parsed.month && now.day < parsed.day)) {
          age--;
        }
        _ageController.text = age.toString();
      }
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
    _identityNumberController.dispose();
    super.dispose();
  }

  Future<void> _selectDateOfBirth() async {
    final now = DateTime.now();
    DateTime initialDate = DateTime(1990, 1, 1);
    if (_dobController.text.isNotEmpty) {
      final parsed = DateTime.tryParse(_dobController.text);
      if (parsed != null && !parsed.isAfter(now)) {
        initialDate = parsed;
      }
    } else if (widget.existingPatient?.dateOfBirth != null) {
      final parsed = DateTime.tryParse(widget.existingPatient!.dateOfBirth);
      if (parsed != null && !parsed.isAfter(now)) {
        initialDate = parsed;
      }
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (picked != null) {
      final formatted = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      int age = now.year - picked.year;
      if (now.month < picked.month || (now.month == picked.month && now.day < picked.day)) {
        age--;
      }
      setState(() {
        _dobController.text = formatted;
        _ageController.text = age.toString();
      });
    }
  }

  String? _sanitizeInput(String? text) {
    if (text == null) return null;
    final cleaned = text.replaceAll('\x00', '').trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  Future<void> _savePatient() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final uuid = widget.existingPatient?.patientUuid ?? 'pat-${DateTime.now().millisecondsSinceEpoch}';
      final ageNum = int.tryParse(_ageController.text.trim());

      final fullName = _sanitizeInput(_fullNameController.text);
      final dob = _sanitizeInput(_dobController.text);
      final mobile = _sanitizeInput(_mobileController.text);
      final identityNum = _sanitizeInput(_identityNumberController.text);
      String? proofOfIdentity;
      if (identityNum != null) {
        proofOfIdentity = '$_identityType|$identityNum';
      }

      if (fullName == null || dob == null || mobile == null) {
        throw Exception('Required fields (Full Name, Date of Birth, Mobile Number) cannot be blank.');
      }

      final patient = Patient(
        id: widget.existingPatient?.id,
        patientUuid: uuid,
        patientCode: _generatedPatientCode,
        fullName: fullName,
        dateOfBirth: dob,
        age: ageNum,
        gender: _gender,
        occupation: _sanitizeInput(_occupationController.text),
        mobileNumber: mobile,
        address: _sanitizeInput(_addressController.text),
        email: _sanitizeInput(_emailController.text),
        emergencyContact: _sanitizeInput(_emergencyContactController.text),
        referralDoctor: _sanitizeInput(_referralDoctorController.text),
        proofOfIdentity: proofOfIdentity,
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
                              onChanged: (v) {
                                final ageNum = int.tryParse(v.trim());
                                if (ageNum != null && ageNum >= 0 && ageNum <= 130) {
                                  final now = DateTime.now();
                                  final approxYear = now.year - ageNum;
                                  final approxDob = "$approxYear-01-01";
                                  if (_dobController.text.isEmpty) {
                                    _dobController.text = approxDob;
                                  }
                                }
                              },
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
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: DropdownButtonFormField<String>(
                              initialValue: _identityType,
                              decoration: const InputDecoration(
                                labelText: 'Identity Type',
                                prefixIcon: Icon(Icons.perm_identity),
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Aadhaar', child: Text('Aadhaar')),
                                DropdownMenuItem(value: 'Passport', child: Text('Passport')),
                                DropdownMenuItem(value: 'Voter ID', child: Text('Voter ID')),
                                DropdownMenuItem(value: 'Driving Licence', child: Text('Driving Licence')),
                                DropdownMenuItem(value: 'Other', child: Text('Other')),
                              ],
                              onChanged: (v) {
                                if (v != null) setState(() => _identityType = v);
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _identityNumberController,
                              maxLength: 20,
                              decoration: const InputDecoration(
                                labelText: 'Identity Number',
                                prefixIcon: Icon(Icons.numbers),
                                border: OutlineInputBorder(),
                                counterText: '',
                              ),
                              validator: (v) {
                                if (v != null && v.trim().isNotEmpty) {
                                  final val = v.trim();
                                  final isAlphanumeric = RegExp(r'^[a-zA-Z0-9]+$').hasMatch(val);
                                  if (!isAlphanumeric) {
                                    return 'Must contain only alphanumeric characters';
                                  }
                                }
                                return null;
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
