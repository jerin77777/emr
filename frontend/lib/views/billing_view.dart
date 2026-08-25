import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/models.dart';
import '../widgets/common_widgets.dart';
import '../utils/date_formatter.dart';

class BillingView extends StatefulWidget {
  final Patient? patient;
  final User currentUser;
  final Bill? existingBill;

  const BillingView({
    super.key,
    this.patient,
    required this.currentUser,
    this.existingBill,
  });

  @override
  State<BillingView> createState() => _BillingViewState();
}

class _BillingViewState extends State<BillingView> {
  final _formKey = GlobalKey<FormState>();

  Patient? _selectedPatient;
  List<Patient> _patients = [];
  bool _isLoadingPatients = false;
  bool _isSaving = false;

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

  @override
  void initState() {
    super.initState();
    _selectedPatient = widget.patient;
    if (widget.existingBill != null) {
      _loadExistingBillData(widget.existingBill!);
    } else {
      _loadBillNumber();
    }
    if (_selectedPatient == null) {
      _fetchPatients();
    }
  }

  void _loadExistingBillData(Bill b) async {
    _billNumber = b.billNumber;
    _consultationController.text = (b.consultationCharges ?? 500.0).toStringAsFixed(2);
    _procedureController.text = (b.procedureCharges ?? 0.0).toStringAsFixed(2);
    _additionalController.text = (b.additionalCharges ?? 0.0).toStringAsFixed(2);
    _discountController.text = (b.discountAmount ?? 0.0).toStringAsFixed(2);
    _paymentStatus = b.paymentStatus ?? 'Paid';
    _paymentMethod = b.paymentMethod ?? 'UPI';

    if (b.patientId != 0 && _selectedPatient == null) {
      final p = await DatabaseHelper.instance.getPatientById(b.patientId);
      if (mounted && p != null) {
        setState(() => _selectedPatient = p);
      }
    }

    if (b.id != null) {
      try {
        final items = await DatabaseHelper.instance.getBillItemsForBill(b.id!);
        if (mounted && items.isNotEmpty) {
          setState(() {
            _lineItems.clear();
            for (final it in items) {
              _lineItems.add({'description': it.itemDescription, 'amount': it.amount});
            }
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _loadBillNumber() async {
    final num = await DatabaseHelper.instance.generateNextBillNumber();
    if (mounted) setState(() => _billNumber = num);
  }

  Future<void> _fetchPatients() async {
    setState(() => _isLoadingPatients = true);
    final pList = await DatabaseHelper.instance.getAllPatients();
    if (mounted) {
      setState(() {
        _patients = pList;
        _isLoadingPatients = false;
      });
    }
  }

  @override
  void dispose() {
    _consultationController.dispose();
    _procedureController.dispose();
    _additionalController.dispose();
    _discountController.dispose();
    _itemDescController.dispose();
    _itemAmountController.dispose();
    super.dispose();
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

  Future<void> _saveBill() async {
    if (_selectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a patient to generate bill.')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final total = _calculatedTotal;

      if (widget.existingBill != null) {
        if (!DateFormatter.isBillEditable(widget.existingBill!.billDate)) {
          throw Exception('The editing window for this invoice closed at midnight + 30 mins. Historical invoices cannot be modified.');
        }

        final updatedBill = widget.existingBill!.copyWith(
          patientId: _selectedPatient!.id!,
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

        final itemsToSave = _lineItems
            .map((e) => BillItem(
                  billId: widget.existingBill!.id!,
                  itemDescription: e['description'],
                  amount: e['amount'],
                ))
            .toList();

        await DatabaseHelper.instance.updateBill(updatedBill, itemsToSave);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invoice ${widget.existingBill!.billNumber} updated successfully!'), backgroundColor: Colors.green),
          );
          Navigator.pop(context, true);
        }
        return;
      }

      final bill = Bill(
        billNumber: _billNumber,
        patientId: _selectedPatient!.id!,
        consultationCharges: _consultationAmount,
        procedureCharges: _procedureAmount,
        additionalCharges: _additionalAmount,
        discountAmount: _discountAmount,
        totalAmount: total,
        paidAmount: _paymentStatus == 'Paid' ? total : 0.0,
        paymentStatus: _paymentStatus,
        paymentMethod: _paymentMethod,
        billDate: DateTime.now().toIso8601String(),
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invoice $_billNumber generated successfully!')),
        );
        Navigator.pop(context, true);
        showDialog(
          context: context,
          builder: (ctx) => BillPrintPreviewDialog(
            bill: bill,
            patient: _selectedPatient!,
            items: _lineItems.map((e) => BillItem(billId: billId, itemDescription: e['description'], amount: e['amount'])).toList(),
          ),
        );
      }
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

  Future<void> _confirmDeleteCurrentBill() async {
    if (widget.existingBill == null || widget.existingBill!.id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Text('Delete Invoice'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete Invoice "${widget.existingBill!.billNumber}" for ₹${widget.existingBill!.totalAmount.toStringAsFixed(2)}?',
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
            child: const Text('Delete Invoice'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await DatabaseHelper.instance.deleteBill(widget.existingBill!.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invoice ${widget.existingBill!.billNumber} deleted successfully.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting invoice: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingBill != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Patient Invoice ($_billNumber)' : 'Generate Patient Invoice & Billing'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        actions: [
          Chip(
            label: Text(_billNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.white,
          ),
          if (isEdit) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white70),
              tooltip: 'Delete Invoice',
              onPressed: _confirmDeleteCurrentBill,
            ),
          ],
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isEdit) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.edit_calendar, color: Colors.amber.shade900, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Editing Invoice ${widget.existingBill!.billNumber}',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${DateFormatter.getBillEditStatusText(widget.existingBill!.billDate)} (Editable within midnight + 30m buffer).',
                              style: TextStyle(color: Colors.amber.shade900, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Left Column: Patient Selection & Charges
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('1. Select Patient *', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (widget.patient != null)
                      Card(
                        color: Colors.teal.shade50,
                        child: ListTile(
                          leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.person, color: Colors.white)),
                          title: Text(widget.patient!.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Patient ID: ${widget.patient!.patientCode} | Mobile: ${widget.patient!.mobileNumber}'),
                        ),
                      )
                    else if (_isLoadingPatients)
                      const CircularProgressIndicator()
                    else
                      DropdownButtonFormField<Patient>(
                        initialValue: _selectedPatient,
                        decoration: const InputDecoration(labelText: 'Patient', border: OutlineInputBorder()),
                        items: _patients.map((p) {
                          return DropdownMenuItem(value: p, child: Text('${p.fullName} (${p.patientCode} - ${p.mobileNumber})'));
                        }).toList(),
                        onChanged: (p) => setState(() => _selectedPatient = p),
                      ),
                    const SizedBox(height: 24),
                    Text('2. Charges Summary', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _consultationController,
                            keyboardType: TextInputType.number,
                            onChanged: (v) => setState(() {}),
                            decoration: const InputDecoration(labelText: 'Consultation Charges (₹)', border: OutlineInputBorder()),
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
                    Text('3. Payment Details', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
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
                  ],
                ),
              ),
              const SizedBox(width: 32),
              // Right Column: Line items break up & Invoice Preview Total Card
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Card(
                      elevation: 4,
                      color: Colors.teal.shade900,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Text('TOTAL AMOUNT PAYABLE', style: TextStyle(color: Colors.white70, letterSpacing: 1.2)),
                            const SizedBox(height: 8),
                            Text(
                              '₹${_calculatedTotal.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const Divider(color: Colors.white24, height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Consultation:', style: TextStyle(color: Colors.white70)),
                                Text('₹${_consultationAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Procedure:', style: TextStyle(color: Colors.white70)),
                                Text('₹${_procedureAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Additional:', style: TextStyle(color: Colors.white70)),
                                Text('₹${_additionalAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Discount:', style: TextStyle(color: Colors.white70)),
                                Text('- ₹${_discountAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isSaving ? null : _saveBill,
                        icon: _isSaving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Icon(isEdit ? Icons.check_circle : Icons.print),
                        label: Text(
                          isEdit ? 'UPDATE INVOICE' : 'GENERATE & SAVE BILL',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
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
}
