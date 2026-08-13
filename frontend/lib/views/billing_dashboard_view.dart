import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/models.dart';
import '../widgets/common_widgets.dart';

class BillingDashboardView extends StatefulWidget {
  final User currentUser;
  final Patient? preSelectedPatient;

  const BillingDashboardView({
    super.key,
    required this.currentUser,
    this.preSelectedPatient,
  });

  @override
  State<BillingDashboardView> createState() => _BillingDashboardViewState();
}

class _BillingDashboardViewState extends State<BillingDashboardView> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();

  List<Patient> _patients = [];
  bool _isLoadingPatients = false;
  Patient? _selectedPatient;

  // Selected Patient Details
  List<PatientVisit> _visits = [];
  List<Bill> _previousBills = [];
  bool _isLoadingDetails = false;

  // Invoice Fields
  String _billNumber = '';
  final _consultationController = TextEditingController(text: '500.0');
  final _procedureController = TextEditingController(text: '0.0');
  final _additionalController = TextEditingController(text: '0.0');
  final _discountController = TextEditingController(text: '0.0');

  String _paymentStatus = 'Paid';
  String _paymentMethod = 'UPI';

  final List<Map<String, dynamic>> _lineItems = [
    {'description': 'Doctor Consultation Fee', 'amount': 500.0},
  ];

  final _itemDescController = TextEditingController();
  final _itemAmountController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPatients();
    if (widget.preSelectedPatient != null) {
      _selectPatient(widget.preSelectedPatient!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _consultationController.dispose();
    _procedureController.dispose();
    _additionalController.dispose();
    _discountController.dispose();
    _itemDescController.dispose();
    _itemAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    setState(() => _isLoadingPatients = true);
    try {
      final query = _searchController.text.trim();
      final pList = await DatabaseHelper.instance.searchPatients(query);
      setState(() {
        _patients = pList;
        _isLoadingPatients = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingPatients = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading patients: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _selectPatient(Patient patient) async {
    setState(() {
      _selectedPatient = patient;
      _isLoadingDetails = true;
      // Reset invoice values
      _consultationController.text = '500.0';
      _procedureController.text = '0.0';
      _additionalController.text = '0.0';
      _discountController.text = '0.0';
      _paymentStatus = 'Paid';
      _paymentMethod = 'UPI';
      _lineItems.clear();
      _lineItems.add({'description': 'Doctor Consultation Fee', 'amount': 500.0});
    });

    try {
      final vList = await DatabaseHelper.instance.getVisitsForPatient(patient.id!);
      final bList = await DatabaseHelper.instance.getBillsForPatient(patient.id!);
      final billNum = await DatabaseHelper.instance.generateNextBillNumber();

      setState(() {
        _visits = vList;
        _previousBills = bList;
        _billNumber = billNum;
        _isLoadingDetails = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingDetails = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading patient details: $e'), backgroundColor: Colors.red),
      );
    }
  }

  double get _consultationAmount => double.tryParse(_consultationController.text) ?? 0.0;
  double get _procedureAmount => double.tryParse(_procedureController.text) ?? 0.0;
  double get _additionalAmount => double.tryParse(_additionalController.text) ?? 0.0;
  double get _discountAmount => double.tryParse(_discountController.text) ?? 0.0;

  double get _calculatedTotal {
    final subtotal = _consultationAmount + _procedureAmount + _additionalAmount;
    final total = subtotal - _discountAmount;
    return total < 0 ? 0.0 : total;
  }

  void _addLineItem() {
    final desc = _itemDescController.text.trim();
    final amt = double.tryParse(_itemAmountController.text) ?? 0.0;
    if (desc.isEmpty || amt <= 0) return;

    setState(() {
      _lineItems.add({'description': desc, 'amount': amt});
      // Add to additional charges automatically
      final currentAdd = double.tryParse(_additionalController.text) ?? 0.0;
      _additionalController.text = (currentAdd + amt).toStringAsFixed(2);
      _itemDescController.clear();
      _itemAmountController.clear();
    });
  }

  void _removeLineItem(int index) {
    setState(() {
      final amt = _lineItems[index]['amount'] as double;
      _lineItems.removeAt(index);
      // Deduct from additional charges if it wasn't the consultation fee
      if (index > 0) {
        final currentAdd = double.tryParse(_additionalController.text) ?? 0.0;
        final newAdd = currentAdd - amt;
        _additionalController.text = (newAdd < 0 ? 0.0 : newAdd).toStringAsFixed(2);
      } else {
        // If they removed consultation fee, set consultation charges text to 0
        _consultationController.text = '0.0';
      }
    });
  }

  Future<void> _saveBill() async {
    if (_selectedPatient == null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final total = _calculatedTotal;
      // Link to latest visit if exists
      final visitId = _visits.isNotEmpty ? _visits.first.id : null;

      final bill = Bill(
        billNumber: _billNumber,
        patientId: _selectedPatient!.id!,
        visitId: visitId,
        consultationCharges: _consultationAmount,
        procedureCharges: _procedureAmount,
        additionalCharges: _additionalAmount,
        discountAmount: _discountAmount,
        totalAmount: total,
        paidAmount: _paymentStatus == 'Paid' ? total : 0.0,
        paymentStatus: _paymentStatus,
        paymentMethod: _paymentMethod,
        syncStatus: 'pending',
      );

      final billId = await DatabaseHelper.instance.insertBill(bill);

      // Save line items
      for (final item in _lineItems) {
        final bItem = BillItem(
          billId: billId,
          itemDescription: item['description'],
          amount: item['amount'],
        );
        await DatabaseHelper.instance.insertBillItem(bItem);
      }

      // Log Audit Event
      await DatabaseHelper.instance.insertAuditLog(
        AuditLog(
          userId: widget.currentUser.id,
          action: 'Create Bill',
          details: 'Generated Bill $_billNumber (Total: ₹$total) for patient ID ${_selectedPatient!.id}',
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invoice $_billNumber generated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      showDialog(
        context: context,
        builder: (ctx) => BillPrintPreviewDialog(
          bill: bill,
          patient: _selectedPatient!,
          items: _lineItems.map((e) => BillItem(billId: billId, itemDescription: e['description'], amount: e['amount'])).toList(),
        ),
      );
      // Refresh details
      _selectPatient(_selectedPatient!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving bill: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Panel: Searchable Patient List
          Container(
            width: 350,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey.shade200)),
              color: Colors.white,
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => _loadPatients(),
                    decoration: InputDecoration(
                      hintText: 'Search patients...',
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
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                Expanded(
                  child: _isLoadingPatients
                      ? const Center(child: CircularProgressIndicator())
                      : _patients.isEmpty
                          ? Center(
                              child: Text(
                                'No patients found',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _patients.length,
                              itemBuilder: (context, index) {
                                final p = _patients[index];
                                final isSelected = _selectedPatient?.id == p.id;
                                return Material(
                                  type: MaterialType.transparency,
                                  child: ListTile(
                                    onTap: () => _selectPatient(p),
                                    selected: isSelected,
                                    selectedTileColor: Colors.teal.shade50,
                                    selectedColor: Colors.teal.shade900,
                                    leading: CircleAvatar(
                                      backgroundColor: isSelected
                                          ? Colors.teal
                                          : (p.gender == 'Male'
                                              ? Colors.blue.shade100
                                              : Colors.pink.shade100),
                                      child: Text(
                                        p.fullName[0].toUpperCase(),
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : Colors.teal.shade900,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      p.fullName,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text('${p.patientCode} • ${p.mobileNumber}'),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),

          // Right Panel: Details and Form
          Expanded(
            child: _selectedPatient == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 80,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Select a patient to start billing',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : _isLoadingDetails
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Patient Demographics Card
                              _buildPatientHeaderCard(),
                              const SizedBox(height: 24),

                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isNarrow = constraints.maxWidth < 900;
                                  if (isNarrow) {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        _buildCurrentVisitSection(),
                                        const SizedBox(height: 24),
                                        _buildPreviousConsultationsSection(),
                                        const SizedBox(height: 24),
                                        _buildPreviousBillsSection(),
                                        const SizedBox(height: 24),
                                        _buildInvoiceFormCard(),
                                      ],
                                    );
                                  } else {
                                    return Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Left side: Timeline/History
                                        Expanded(
                                          flex: 3,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _buildCurrentVisitSection(),
                                              const SizedBox(height: 24),
                                              _buildPreviousConsultationsSection(),
                                              const SizedBox(height: 24),
                                              _buildPreviousBillsSection(),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 24),

                                        // Right side: Billing Form
                                        Expanded(
                                          flex: 4,
                                          child: _buildInvoiceFormCard(),
                                        ),
                                      ],
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientHeaderCard() {
    final p = _selectedPatient!;
    return Card(
      color: Colors.teal.shade50,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.teal.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.teal.shade200,
              child: Text(
                p.fullName[0].toUpperCase(),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        p.fullName,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Chip(
                        label: Text(p.gender, style: const TextStyle(fontSize: 12)),
                        backgroundColor: p.gender == 'Male' ? Colors.blue.shade100 : Colors.pink.shade100,
                      ),
                      Chip(
                        label: Text('${p.age ?? "N/A"} yrs'),
                        backgroundColor: Colors.grey.shade200,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 24,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.numbers, size: 16, color: Colors.teal.shade700),
                          const SizedBox(width: 4),
                          const Text('Patient ID: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(p.patientCode),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.phone, size: 16, color: Colors.teal.shade700),
                          const SizedBox(width: 4),
                          const Text('Mobile: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(p.mobileNumber),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cake, size: 16, color: Colors.teal.shade700),
                          const SizedBox(width: 4),
                          const Text('DOB: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(p.dateOfBirth),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentVisitSection() {
    if (_visits.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 1,
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current Visit Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Divider(),
              SizedBox(height: 8),
              Text('No visits recorded for this patient. Billing will be generated as independent invoice.'),
            ],
          ),
        ),
      );
    }

    final latestVisit = _visits.first;
    final vitalsText = latestVisit.formattedVitals(includePlaceholders: true);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Current Visit Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),
                Chip(
                  label: Text('Visit #${latestVisit.visitNumber}'),
                  backgroundColor: Colors.teal.shade50,
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            _detailRow('Date', latestVisit.visitDate ?? 'N/A'),
            _detailRow('Chief Complaint', latestVisit.chiefComplaint ?? 'None'),
            _detailRow('Diagnosis', latestVisit.diagnosis ?? 'None'),
            if (latestVisit.diagnosisCode?.isNotEmpty == true)
              _detailRow('ICD-10 Code', latestVisit.diagnosisCode!),
            _detailRow('Vitals', vitalsText),
            _detailRow('Advice', latestVisit.advice ?? 'None'),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviousConsultationsSection() {
    if (_visits.length <= 1) {
      return const SizedBox.shrink();
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Previous Consultations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _visits.length - 1,
              itemBuilder: (context, index) {
                final visit = _visits[index + 1];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Visit #${visit.visitNumber} (${visit.visitDate})', style: const TextStyle(fontWeight: FontWeight.w500)),
                      Text(visit.diagnosis ?? 'No diagnosis', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviousBillsSection() {
    if (_previousBills.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Billing History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _previousBills.length,
              itemBuilder: (context, index) {
                final bill = _previousBills[index];
                final status = bill.paymentStatus ?? 'Pending';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => BillPrintPreviewDialog(bill: bill, patient: _selectedPatient!),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      child: Row(
                        children: [
                          Icon(
                            status == 'Paid' ? Icons.check_circle : Icons.pending,
                            color: status == 'Paid' ? Colors.green : Colors.amber.shade800,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(bill.billNumber, style: const TextStyle(fontWeight: FontWeight.w500)),
                          const Spacer(),
                          Text('₹${bill.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: status == 'Paid' ? Colors.green.shade50 : Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 11,
                                color: status == 'Paid' ? Colors.green.shade900 : Colors.amber.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.print, size: 18, color: Colors.teal),
                            tooltip: 'Print Invoice',
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => BillPrintPreviewDialog(bill: bill, patient: _selectedPatient!),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceFormCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Generate Invoice', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
                Chip(
                  label: Text(_billNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                  backgroundColor: Colors.teal.shade50,
                ),
              ],
            ),
            const Divider(height: 24),

            // Charges inputs
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _consultationController,
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      setState(() {
                        // Sync consultation fee line item
                        if (_lineItems.isNotEmpty) {
                          _lineItems[0]['amount'] = double.tryParse(v) ?? 0.0;
                        }
                      });
                    },
                    decoration: const InputDecoration(labelText: 'Consultation Fee (₹)', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _procedureController,
                    keyboardType: TextInputType.number,
                    onChanged: (v) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Procedure Charges (₹)', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _additionalController,
                    keyboardType: TextInputType.number,
                    onChanged: (v) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Additional Charges (₹)', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _discountController,
                    keyboardType: TextInputType.number,
                    onChanged: (v) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Discount Amount (₹)', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Line items section
            const Text('Billable Line Items', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _lineItems.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = _lineItems[index];
                  return ListTile(
                    dense: true,
                    title: Text(item['description']),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('₹${(item['amount'] as double).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 18),
                          onPressed: () => _removeLineItem(index),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Add line item form
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _itemDescController,
                    decoration: const InputDecoration(hintText: 'Item Description', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _itemAmountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'Amount (₹)', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addLineItem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Payment settings
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _paymentStatus,
                    decoration: const InputDecoration(labelText: 'Payment Status', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'Paid', child: Text('Paid')),
                      DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                      DropdownMenuItem(value: 'Partial', child: Text('Partial')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _paymentStatus = v);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _paymentMethod,
                    decoration: const InputDecoration(labelText: 'Payment Method', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'UPI', child: Text('UPI / QR')),
                      DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'Card', child: Text('Card / POS')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _paymentMethod = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Total Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.teal.shade900,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Payable:', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(
                    '₹${_calculatedTotal.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _isSaving ? null : _saveBill,
                icon: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.print),
                label: const Text('GENERATE & SAVE BILL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey.shade900),
            ),
          ),
        ],
      ),
    );
  }
}
