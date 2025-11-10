import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

/// Push with:
/// Navigator.pushNamed(context, PaymentAdditionalPage.route, arguments: {
///   'requestId': requestId,
///   'extra': 25.50, // suggested extra
/// });
class PaymentAdditionalPage extends StatefulWidget {
  static const route = '/payment/additional';
  const PaymentAdditionalPage({super.key});
  @override State<PaymentAdditionalPage> createState() => _PaymentAdditionalPageState();
}

class _PaymentAdditionalPageState extends State<PaymentAdditionalPage> {
  final _form = GlobalKey<FormState>();
  final _refNo = TextEditingController();
  final _amount = TextEditingController();
  DateTime _date = DateTime.now();
  final _picker = ImagePicker();
  XFile? _file; bool _busy=false;

  @override void dispose(){_refNo.dispose();_amount.dispose();super.dispose();}

  Future<Uint8List> _compress(Uint8List b) async {
    try { final dec = img.decodeImage(b); if (dec==null) return b;
    return Uint8List.fromList(img.encodeJpg(dec, quality: 80)); } catch(_){ return b; }
  }

  Future<String?> _upload(String uid, String reqId) async {
    if (_file==null) return null;
    final by0 = await _file!.readAsBytes();
    final by = await _compress(by0);
    final ref = FirebaseStorage.instance.ref('payments/$uid/$reqId/additional.jpg');
    final snap = await ref.putData(by, SettableMetadata(contentType: 'image/jpeg'));
    return snap.ref.getDownloadURL();
  }

  @override
  Widget build(BuildContext context) {
    final args = (ModalRoute.of(context)?.settings.arguments as Map?) ?? {};
    final String requestId = args['requestId'];
    final double extra = (args['extra'] as num).toDouble();
    if (_amount.text.isEmpty) _amount.text = extra.toStringAsFixed(2);

    return Scaffold(
      appBar: AppBar(title: const Text('Additional Payment')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Please kindly bank in to:'),
            const Text('Bank Holder Name: Ecc App'),
            const Text('Bank Account: 05450247391'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.attach_file), label: Text(_file==null?'Attach File':'Change File'),
              onPressed: () async {
                final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                if (x!=null) setState(()=>_file=x);
              },
            ),
            if (_file != null)
              ListTile(
                dense: true,
                leading: const Icon(Icons.attachment),
                title: Text(_file!.name),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _file = null),
                ),
              ),
            const SizedBox(height: 8),
            Form(
              key: _form,
              child: Column(children: [
                TextFormField(controller:_refNo, decoration: const InputDecoration(labelText:'Reference Number'),
                    validator:(v)=> (v==null||v.trim().isEmpty)?'Required':null),
                const SizedBox(height: 8),
                TextFormField(controller:_amount, decoration: const InputDecoration(labelText:'Amount (RM)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal:true),
                    validator:(v)=> (double.tryParse((v??'').trim())??0)<=0 ? 'Enter amount':null),
              ]),
            ),
            const SizedBox(height: 16),
            SizedBox(height:48, child: ElevatedButton(
              onPressed: () async {
                if(!_form.currentState!.validate()||_file==null) return;
                setState(()=>_busy=true);
                final uid = FirebaseAuth.instance.currentUser!.uid;
                final url = await _upload(uid, requestId); if (url==null){setState(()=>_busy=false);return;}

                await FirebaseFirestore.instance.collection('bookingRequests').doc(requestId).update({
                  'payment': {
                    'type': 'additional',
                    'referenceNo': _refNo.text.trim(),
                    'amount': double.parse(_amount.text.trim()),
                    'date': Timestamp.fromDate(_date),
                    'receiptUrl': url,
                    'submittedAt': FieldValue.serverTimestamp(),
                  },
                  'status': 'additional_submitted',
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                if(!mounted) return; Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Additional payment submitted.')),
                );
              },
              child: const Text('Submit'),
            )),
          ],
        ),
      ),
    );
  }
}
