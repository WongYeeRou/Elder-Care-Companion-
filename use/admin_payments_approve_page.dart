// lib/admin_payments_approve_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_user_request_detail.dart';

class AdminPaymentsApprovePage extends StatelessWidget {
  static const route = '/admin/payments';
  const AdminPaymentsApprovePage({super.key});

  @override
  Widget build(BuildContext context) {
    final pending = FirebaseFirestore.instance
        .collection('payments')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Money Request from user')),
      body: StreamBuilder<QuerySnapshot>(
        stream: pending,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final docs = snap.data?.docs ?? const [];
          if (docs.isEmpty) {
            return const Center(child: Text('No pending payments'));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final doc = docs[i]; // <-- define it
              final p = doc.data()! as Map<String, dynamic>;

              final amount = (p['amount'] ?? 0).toString();
              final refNum = (p['referenceNumber'] ?? '').toString();
              final createdAtTs = p['createdAt'];
              final createdAt = createdAtTs is Timestamp
                  ? createdAtTs.toDate().toLocal().toString().substring(0, 16)
                  : '-';

              return ListTile(
                title: Text('RM $amount  •  Ref: $refNum'),
                subtitle: Text('User: ${p['userUid']}  •  Date: $createdAt'),
                trailing: TextButton(
                  child: const Text('Manage'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AdminUserRequestDetail(requestId: doc.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
