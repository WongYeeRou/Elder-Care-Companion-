// lib/admin_user_request_detail.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


class AdminUserRequestDetail extends StatelessWidget {
  final String requestId;
  const AdminUserRequestDetail({super.key, required this.requestId});

  @override
  Widget build(BuildContext context) {
    final docRef =
    FirebaseFirestore.instance.collection('payments').doc(requestId);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage User Request')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: docRef.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('Request not found.'));
          }

          final m = snap.data!.data()!;

          // Fallback-friendly getters (different projects use slightly different keys)
          String _getStr(List keys) =>
              keys.map((k) => (m[k] ?? '') as String? ?? '').firstWhere(
                    (v) => v.isNotEmpty,
                orElse: () => '',
              );

          final username = _getStr(['username', 'userName', 'user']);
          final userUid = _getStr(['userUid', 'userId', 'uid']);
          final type = _getStr(['type', 'requestType']);
          final status = _getStr(['status']);
          final amount = (m['amount'] ?? m['total'] ?? '').toString();

          final refNo = _getStr(
              ['referenceNumber', 'referencesNumber', 'refNo', 'refNumber']);
          final receiptUrl =
          _getStr(['receiptUrl', 'fileUrl', 'attachmentUrl', 'receipt']);

          final ts = (m['date'] ?? m['uploadedAt'] ?? m['createdAt']);
          String dateStr = '-';
          if (ts is Timestamp) {
            final d = ts.toDate().toLocal();
            dateStr =
            '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
                '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _labelValue('User', username.isNotEmpty ? username : userUid),
                const SizedBox(height: 16),
                _labelValue('Type', type),
                const SizedBox(height: 16),
                _labelValue('Status', status),
                const SizedBox(height: 16),
                _labelValue('Amount (RM)', amount),

                // New fields
                const SizedBox(height: 16),
                _labelValue('Reference Number', refNo.isEmpty ? '-' : refNo),
                const SizedBox(height: 16),
                _labelValue('Date Uploaded', dateStr),

                const SizedBox(height: 16),
                if (receiptUrl.isNotEmpty)
                  _AttachmentTile(url: receiptUrl)
                else
                  _labelValue('Attachment', '(none)'),

                const Spacer(),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await docRef.update({
                            'status': 'rejected',
                            'reviewedAt': FieldValue.serverTimestamp(),
                          });
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          // Approve logic; expand later per your flow
                          await docRef.update({
                            'status': 'approved',
                            'reviewedAt': FieldValue.serverTimestamp(),
                          });
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: const Text('Approve'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  final String url;
  const _AttachmentTile({required this.url});

  @override
  Widget build(BuildContext context) {
    final looksLikeImage = url.endsWith('.jpg') ||
        url.endsWith('.jpeg') ||
        url.endsWith('.png') ||
        url.contains('image');

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Attachment',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    url,
                    maxLines: 2,
                    style: TextStyle(color: Colors.black.withOpacity(.75)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Copy URL',
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: url)).then((_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('URL copied')),
                        );
                      }),
                  icon: const Icon(Icons.copy),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      child: SizedBox(
                        width: 360,
                        height: 480,
                        child: looksLikeImage
                            ? InteractiveViewer(
                          child: Image.network(url, fit: BoxFit.contain),
                        )
                            : Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Text('Attachment'),
                              const SizedBox(height: 12),
                              SelectableText(
                                url,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.blue),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Preview not available. Copy the URL and open it in a browser.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('View attachment'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Widget _labelValue(String label, String value) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: TextStyle(
              color: Colors.black.withOpacity(.65),
              fontWeight: FontWeight.w500)),
      const SizedBox(height: 4),
      Text(value.isEmpty ? '-' : value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
    ],
  );
}
