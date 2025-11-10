import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class UserBookingDetailPage extends StatelessWidget {
  final String bookingId;
  const UserBookingDetailPage({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context) {
    final dfDate = DateFormat('yyyy-MM-dd');
    final tf = DateFormat('HH:mm');

    final stream = FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingId)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Booking Detail')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.data!.exists) {
            return const Center(child: Text('Booking not found.'));
          }
          final m = snap.data!.data()!;

          // schedule
          final startTs = m['schedule']?['startAt'];
          final endTs = m['schedule']?['endAt'];
          final start = (startTs is Timestamp) ? startTs.toDate() : null;
          final end = (endTs is Timestamp) ? endTs.toDate() : null;

          // recipient/client
          final rec = (m['recipient'] as Map?) ?? const {};
          final rate = (m['ratePerHour'] ?? 0).toString();
          final total = (m['total'] ?? 0).toString();
          final estH  = (m['estimatedDurationHours'] ?? 1).toString();

          // caregiver info
          final cgMini = (m['caregiver'] as Map?) ?? const {};
          final cgId = (m['caregiverId'] ?? cgMini['id'] ?? '').toString();
          final inlineName = (cgMini['name'] ?? '').toString();
          final inlineContact = (cgMini['contact'] ?? '').toString();

          Widget caregiverBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kv('Name', inlineName.isNotEmpty ? inlineName : '(assigned caregiver)'),
              const SizedBox(height: 6),
              _kv('Contact', inlineContact.isNotEmpty ? inlineContact : '-'),
            ],
          );

          // fallback: if missing, fetch caregiver doc
          if ((inlineName.isEmpty || inlineContact.isEmpty) && cgId.isNotEmpty) {
            caregiverBlock = StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('caregivers').doc(cgId).snapshots(),
              builder: (context, cgSnap) {
                final cg = cgSnap.data?.data() ?? const {};
                final n = (cg['fullName'] ?? inlineName).toString();
                final c = (cg['contact'] ?? inlineContact).toString();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _kv('Name', n.isNotEmpty ? n : '(assigned caregiver)'),
                    const SizedBox(height: 6),
                    _kv('Contact', c.isNotEmpty ? c : '-'),
                  ],
                );
              },
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text(
                'Booking ID: ${snap.data!.id}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (start != null && end != null) ...[
                Text('Date: ${dfDate.format(start)}'),
                Text('Time: ${tf.format(start)} – ${tf.format(end)}'),
                const Divider(height: 28),
              ],

              const Text('Details of Service Recipient',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _kv('Full Name', (rec['fullName'] ?? '').toString()),
              _kv('Gender', (rec['gender'] ?? '').toString()),
              _kv('Contact Number', (rec['contact'] ?? '').toString()),
              _kv('Relationship', (rec['relationship'] ?? '').toString()),
              _kv('Age', (rec['age'] ?? '').toString()),
              _kv('House Address', (rec['address'] ?? '').toString()),
              const Divider(height: 28),

              const Text('Caregiver',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              caregiverBlock,
              const Divider(height: 28),

              const Text('Payment Summary',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _kv('Rate per Hour', 'RM $rate'),
              _kv('Estimated Duration', '${estH}h'),
              _kv('Total Payment', 'RM $total'),
            ],
          );
        },
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k,
            style: TextStyle(
                color: Colors.black.withOpacity(.65),
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(v.isEmpty ? '-' : v,
            style:
            const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}
