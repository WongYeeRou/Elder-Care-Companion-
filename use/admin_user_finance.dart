import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';

/// Admin page – lists bookingRequests that need review:
///  - payment_submitted  (Cash-In)
///  - additional_submitted (Additional after service)
///
/// No composite index required (we avoid orderBy on the server).
class AdminUserFinancePage extends StatelessWidget {
  const AdminUserFinancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection('bookingRequests')
        .where('status', whereIn: const [
      'payment_submitted',
      'additional_submitted',
    ]);

    return Scaffold(
      appBar: AppBar(title: const Text('Money Requests (Users)')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error: ${snap.error}'),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = [...snap.data!.docs]..sort((a, b) {
            final ta = (a.data()['updatedAt'] ?? a.data()['createdAt']);
            final tb = (b.data()['updatedAt'] ?? b.data()['createdAt']);
            final da = ta is Timestamp ? ta.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
            final db = tb is Timestamp ? tb.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
            return db.compareTo(da);
          });

          if (docs.isEmpty) {
            return const Center(child: Text('No pending requests.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final d = docs[i];
              final m = d.data();
              final user = (m['client']?['name'] ?? m['userUid']).toString();
              final type = (m['payment']?['type'] ?? 'unknown').toString();
              final amt  = (m['payment']?['amount'] ?? 0).toString();
              final whenTs = (m['updatedAt'] ?? m['createdAt']);
              final when = whenTs is Timestamp
                  ? DateFormat('yyyy-MM-dd HH:mm').format(whenTs.toDate())
                  : '-';

              return Card(
                child: ListTile(
                  title: Text('$user  •  ${type.toUpperCase()}  •  RM $amt'),
                  subtitle: Text('Req: ${d.id}  •  $when'),
                  trailing: TextButton(
                    child: const Text('Manage'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _UserMoneyDetail(docId: d.id, data: m),
                      ),
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

class _UserMoneyDetail extends StatefulWidget {
  final String docId;
  final Map<String,dynamic> data;
  const _UserMoneyDetail({required this.docId, required this.data});

  @override
  State<_UserMoneyDetail> createState() => _UserMoneyDetailState();
}

class _UserMoneyDetailState extends State<_UserMoneyDetail> {
  final _picker = ImagePicker();
  XFile? _receipt;

  Future<Uint8List> _compress(Uint8List b) async {
    try {
      final dec = img.decodeImage(b); if (dec == null) return b;
      final r = dec.width > 1200 ? img.copyResize(dec, width: 1200) : dec;
      return Uint8List.fromList(img.encodeJpg(r, quality: 80));
    } catch (_) { return b; }
  }

  Future<String?> _uploadReceipt(String uid, String id) async {
    if (_receipt == null) return null;
    final raw = await _receipt!.readAsBytes();
    final bytes = await _compress(raw);
    final ref = FirebaseStorage.instance.ref('admin/payments/$uid/$id/bank_receipt.jpg');
    final snap = await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return snap.ref.getDownloadURL();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.data;
    final userUid = (m['userUid'] ?? '').toString();
    final payment = (m['payment'] as Map<String, dynamic>?) ?? {};
    final type = (payment['type'] ?? 'unknown').toString(); // 'cash_in' | 'additional'
    final amt  = (payment['amount'] ?? 0).toString();

    final refNo = (payment['referenceNo'] ?? '').toString();
    final Timestamp? payTs = payment['date'] as Timestamp?;
    final dateStr = payTs != null ? DateFormat('yyyy-MM-dd').format(payTs.toDate()) : '-';
    final receiptUrl = (payment['receiptUrl'] ?? '').toString();

    final reqRef  = FirebaseFirestore.instance.collection('bookingRequests').doc(widget.docId);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage User Request')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _kv('User', m['client']?['name'] ?? userUid),
          _kv('Type', type),
          _kv('Status', m['status']),
          _kv('Amount (RM)', amt),
          const SizedBox(height: 12),
          _kv('Reference Number', refNo.isEmpty ? '-' : refNo),
          _kv('Date', dateStr),
          const SizedBox(height: 12),

          if (receiptUrl.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Receipt attached',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    TextButton(
                      child: const Text('View'),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          child: SizedBox(
                            width: 360,
                            height: 480,
                            child: InteractiveViewer(
                              child: Image.network(
                                receiptUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: SelectableText(receiptUrl),
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            _kv('Receipt', '(none)'),

          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(
              child: const Text('Reject'),
              onPressed: () async {
                await reqRef.update({'status':'rejected_by_admin','updatedAt':FieldValue.serverTimestamp()});
                if (context.mounted) Navigator.pop(context);
              },
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              child: const Text('Approve'),
              onPressed: () async {
                String? adminReceiptUrl;
                if (type != 'cash_in') {
                  adminReceiptUrl = await _uploadReceipt(userUid, widget.docId);
                }

                // --- inside onPressed: () async { ... } for Approve ---

                if (type == 'cash_in') {
                  final reqRef = FirebaseFirestore.instance.collection('bookingRequests').doc(widget.docId);
                  final reqSnap = await reqRef.get();
                  final r = reqSnap.data()!;

                  // pull caregiver for denormalized display fields
                  final cgId = (r['caregiverUid'] ?? '').toString();
                  Map<String, dynamic> caregiverMini = {};
                  if (cgId.isNotEmpty) {
                    final cgSnap = await FirebaseFirestore.instance
                        .collection('caregivers')
                        .doc(cgId)
                        .get();
                    final cg = cgSnap.data() ?? {};
                    caregiverMini = {
                      'id': cgId,
                      'name': (cg['fullName'] ?? '').toString(),
                      'contact': (cg['contact'] ?? '').toString(),
                      'profilePic': (cg['attachments']?['profilePic'] ?? '').toString(),
                    };
                  }

                  final bookRef = FirebaseFirestore.instance.collection('bookings').doc();

                  await FirebaseFirestore.instance.runTransaction((tx) async {
                    // 1) create booking
                    tx.set(bookRef, {
                      'requestId': reqRef.id,
                      'userId': r['userUid'],
                      'caregiverId': cgId,
                      'caregiver': caregiverMini,           // <-- denormalized for detail page

                      'client': r['client'],
                      'recipient': r['recipient'],
                      'schedule': {
                        'startAt': r['startAt'],
                        'endAt': r['endAt'],
                      },
                      'ratePerHour': r['ratePerHour'],
                      'estimatedDurationHours': 1,
                      'total': r['estTotal'],
                      'status': 'upcoming',
                      'createdAt': FieldValue.serverTimestamp(),
                      'updatedAt': FieldValue.serverTimestamp(),
                      'startedAt': null,
                      'completion': {
                        'result': '',
                        'actualMinutes': null,
                        'suggestedExtra': null,
                      },
                    });

                    // 2) mark request approved
                    tx.update(reqRef, {
                      'status': 'approved',
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                  });
                }
                else {
                  // Additional: mark request completed, complete booking, credit caregiver
                  final updates = <String,dynamic>{
                    'status': 'completed',
                    'approvedBy': 'admin',
                    'updatedAt': FieldValue.serverTimestamp(),
                  };
                  if (adminReceiptUrl != null) {
                    updates['adminBankReceiptUrl'] = adminReceiptUrl;
                  }
                  await reqRef.update(updates);

                  // Find booking by requestId
                  final booking = await FirebaseFirestore.instance
                      .collection('bookings')
                      .where('requestId', isEqualTo: reqRef.id)
                      .limit(1).get();

                  if (booking.docs.isNotEmpty) {
                    final bRef = booking.docs.first.reference;
                    final bData = booking.docs.first.data();
                    await bRef.update({
                      'status': 'completed',
                      'updatedAt': FieldValue.serverTimestamp(),
                    });

                    // Credit caregiver wallet: base 1h + extra amount
                    final caregiverUid = (widget.data['caregiverUid'] ?? '').toString();
                    final extra = (widget.data['payment']?['amount'] ?? 0);
                    if (caregiverUid.isNotEmpty) {
                      final cgRef = FirebaseFirestore.instance.collection('caregivers').doc(caregiverUid);
                      await FirebaseFirestore.instance.runTransaction((tx) async {
                        final cgSnap = await tx.get(cgRef);
                        final cur = (cgSnap.data()?['walletBalance'] ?? 0).toDouble();
                        final add = (extra as num?)?.toDouble() ?? 0.0;
                        final base = (bData['total'] as num?)?.toDouble() ?? 0.0;
                        tx.update(cgRef, {'walletBalance': cur + base + add});
                      });
                    }
                  }
                }

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
