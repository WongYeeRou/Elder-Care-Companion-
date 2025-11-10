// lib/payment_cash_in.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

/// Route push with:
/// Navigator.pushNamed(context, '/payment/cash-in', arguments: {
///   'requestId': requestId,            // bookingRequests doc id
///   'estTotal':  totalAmountDouble,    // prefill amount
/// });
class PaymentCashInPage extends StatefulWidget {
  static const route = '/payment/cash-in';
  const PaymentCashInPage({super.key});

  @override
  State<PaymentCashInPage> createState() => _PaymentCashInPageState();
}

class _PaymentCashInPageState extends State<PaymentCashInPage> {
  final _form = GlobalKey<FormState>();
  final _refNo = TextEditingController();
  final _amount = TextEditingController();
  DateTime _date = DateTime.now();

  final _picker = ImagePicker();
  XFile? _receiptFile;
  bool _busy = false;

  @override
  void dispose() {
    _refNo.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x != null) setState(() => _receiptFile = x);
  }

  Future<Uint8List> _compress(Uint8List input) async {
    try {
      final decoded = img.decodeImage(input);
      if (decoded == null) return input;
      const maxW = 1200;
      final resized = decoded.width > maxW ? img.copyResize(decoded, width: maxW) : decoded;
      return Uint8List.fromList(img.encodeJpg(resized, quality: 80));
    } catch (_) {
      return input;
    }
  }

  FirebaseStorage _storage() => FirebaseStorage.instance;

  Future<String?> _uploadReceipt({
    required String uid,
    required String requestId,
    required XFile file,
  }) async {
    try {
      final bytes0 = await file.readAsBytes();
      final bytes = await _compress(bytes0);
      if (bytes.length > 5 * 1024 * 1024) {
        _snack('File too large after compression (>5MB).');
        return null;
      }
      final ts = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage()
          .ref('payments/$uid/$requestId/receipt_$ts.jpg');
      final snap = await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return snap.ref.getDownloadURL();
    } on FirebaseException catch (e) {
      _snack('Upload error: ${e.code}');
      return null;
    } catch (e) {
      _snack('Upload failed.');
      return null;
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map?;
    if (args == null) {
      return const Scaffold(body: Center(child: Text('Missing payment args')));
    }
    final requestId = args['requestId'] as String;
    final estTotal = (args['estTotal'] as num?)?.toDouble() ?? 0;
    if (_amount.text.isEmpty && estTotal > 0) _amount.text = estTotal.toStringAsFixed(2);

    final df = DateFormat('yyyy-MM-dd');

    return Scaffold(
      appBar: AppBar(title: const Text('Payment Details')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            const Text('Please kindly bank in to:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('Bank Holder Name: Ecc App'),
            const Text('Bank Account: 05450247391'),
            const SizedBox(height: 12),

            // Attach file button
            Center(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.link),
                label: Text(_receiptFile == null ? 'Attach File' : 'Change File'),
                onPressed: _pickReceipt,
              ),
            ),
            if (_receiptFile != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.attachment),
                  title: Text(_receiptFile!.name),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _receiptFile = null),
                  ),
                ),
              ),

            const SizedBox(height: 8),
            Form(
              key: _form,
              child: Column(
                children: [
                  TextFormField(
                    controller: _refNo,
                    decoration: const InputDecoration(labelText: 'Reference Number'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              firstDate: DateTime(2024, 1, 1),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                              initialDate: _date,
                            );
                            if (picked != null) setState(() => _date = picked);
                          },
                          child: Text('Date: ${df.format(_date)}'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _amount,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Total Amount (RM)'),
                          validator: (v) {
                            final n = double.tryParse((v ?? '').trim());
                            if (n == null || n <= 0) return 'Enter a valid amount';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () => _submit(requestId),
                child: const Text('Submit'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(String requestId) async {
    if (!_form.currentState!.validate()) return;
    if (_receiptFile == null) {
      _snack('Please attach your bank-in receipt.');
      return;
    }
    setState(() => _busy = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final url = await _uploadReceipt(
        uid: uid,
        requestId: requestId,
        file: _receiptFile!,
      );
      if (url == null) { setState(() => _busy = false); return; }

      final ref = FirebaseFirestore.instance.collection('bookingRequests').doc(requestId);
      await ref.update({
        'payment': {
          'type': 'cash_in',
          'referenceNo': _refNo.text.trim(),
          'amount': double.parse(_amount.text.trim()),
          'date': Timestamp.fromDate(_date),
          'receiptUrl': url,
          'submittedAt': FieldValue.serverTimestamp(),
        },
        'status': 'payment_submitted',      // admin will verify, then create booking
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _snack('Payment submitted. Await admin confirmation.');
      Navigator.pop(context);
    } on FirebaseException catch (e) {
      _snack('Error: ${e.code}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
