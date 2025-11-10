import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

class AdminCaregiverFinance extends StatelessWidget {
  const AdminCaregiverFinance({super.key});

  @override
  Widget build(BuildContext context) {
    // withdrawals collection: caregiverUid, amount, status=pending
    final q = FirebaseFirestore.instance
        .collection('withdrawals')
        .where('status', isEqualTo: 'pending');

    return Scaffold(
      appBar: AppBar(title: const Text('Caregiver Withdrawals')),
      body: StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No pending withdrawals.'));
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final d = docs[i]; final m = d.data();
              final cg = (m['caregiverUsername'] ?? m['caregiverUid']).toString();
              final amt = (m['amount'] ?? 0).toString();
              return Card(
                child: ListTile(
                  title: Text('$cg  •  RM $amt'),
                  subtitle: Text('ID: ${d.id}'),
                  trailing: TextButton(
                    child: const Text('Manage'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => _WithdrawDetail(id: d.id, data: m)),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _WithdrawDetail extends StatefulWidget {
  final String id; final Map<String,dynamic> data;
  const _WithdrawDetail({required this.id, required this.data});

  @override
  State<_WithdrawDetail> createState() => _WithdrawDetailState();
}

class _WithdrawDetailState extends State<_WithdrawDetail> {
  final _picker = ImagePicker();
  XFile? _receipt;

  Future<Uint8List> _compress(Uint8List b) async {
    try { final dec = img.decodeImage(b); if (dec==null) return b;
    final r = dec.width>1200? img.copyResize(dec, width:1200):dec;
    return Uint8List.fromList(img.encodeJpg(r, quality:80));
    } catch (_) { return b; }
  }

  Future<String?> _uploadReceipt(String caregiverUid, String id) async {
    if (_receipt == null) return null;
    final raw = await _receipt!.readAsBytes();
    final bytes = await _compress(raw);
    final ref = FirebaseStorage.instance.ref('withdrawals/$caregiverUid/$id/receipt.jpg');
    final snap = await ref.putData(bytes, SettableMetadata(contentType:'image/jpeg'));
    return snap.ref.getDownloadURL();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.data;
    final uid = (m['caregiverUid'] ?? '').toString();
    final amt = (m['amount'] ?? 0).toString();
    final ref = FirebaseFirestore.instance.collection('withdrawals').doc(widget.id);

    return Scaffold(
      appBar: AppBar(title: const Text('Withdrawal Detail')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _kv('Caregiver', m['caregiverUsername'] ?? uid),
          _kv('Amount (RM)', amt),
          _kv('Status', m['status']),
          const SizedBox(height: 12),
          Row(children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.attachment),
              label: Text(_receipt == null ? 'Attach Bank Receipt' : 'Replace'),
              onPressed: () async {
                final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                if (x != null) setState(()=>_receipt = x);
              },
            ),
            const SizedBox(width: 8),
            if (_receipt != null) Text(_receipt!.name),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(
              child: const Text('Reject'),
              onPressed: () async {
                await ref.update({'status':'rejected','updatedAt':FieldValue.serverTimestamp()});
                if (context.mounted) Navigator.pop(context);
              },
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              child: const Text('Send'),
              onPressed: () async {
                final url = await _uploadReceipt(uid, widget.id);
                await ref.update({
                  'status':'paid',
                  'adminReceiptUrl': url,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                if (context.mounted) Navigator.pop(context);
              },
            )),
          ]),
        ],
      ),
    );
  }

  Widget _kv(String k, Object? v) => ListTile(dense: true, title: Text(k), subtitle: Text(v?.toString() ?? '-'));
}
