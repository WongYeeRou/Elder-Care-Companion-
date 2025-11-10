import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminFeedbacksPage extends StatelessWidget {
  const AdminFeedbacksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance.collection('feedback').orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Feedbacks')),
      body: StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No feedback yet.'));
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final d = docs[i]; final m = d.data();
              final subject = (m['subject'] ?? '').toString();
              final status  = (m['status'] ?? 'new').toString();
              final userUid = (m['userUid'] ?? '').toString();
              return Card(
                child: ListTile(
                  title: Text(subject),
                  subtitle: Text('From: $userUid  •  $status'),
                  trailing: TextButton(
                    child: const Text('View'),
                    onPressed: () => _open(context, d),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _open(BuildContext context, QueryDocumentSnapshot<Map<String,dynamic>> d) {
    final m = d.data();
    final ctrl = TextEditingController(text: (m['status'] ?? 'new').toString());
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text((m['subject'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text((m['message'] ?? '').toString()),
            const Divider(),
            TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Status (new/in_progress/resolved)')),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                await d.reference.update({'status': ctrl.text.trim()});
                if (Navigator.canPop(context)) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
