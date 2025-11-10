// lib/user_my_bookings.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UserMyBookingsPage extends StatelessWidget {
  static const route = '/user/my-bookings';
  const UserMyBookingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: TabBar(
          labelColor: Colors.teal,
          unselectedLabelColor: Colors.black54,
          tabs: [
            Tab(text: 'Upcoming'),
            Tab(text: 'Ongoing'),
            Tab(text: 'Completed'),
          ],
        ),
        body: TabBarView(
          children: [
            _UserBookingList(status: 'upcoming'),
            _UserBookingList(status: 'ongoing'),
            _UserBookingList(status: 'completed'),
          ],
        ),
      ),
    );
  }
}

class _UserBookingList extends StatelessWidget {
  final String status;
  const _UserBookingList({required this.status});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Please sign in.'));

    final q = FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: uid)
        .where('status', isEqualTo: status);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final raw = snap.data?.docs ?? [];
        if (raw.isEmpty) {
          return Center(
            child: Text(
              status == 'upcoming'
                  ? 'No upcoming bookings.'
                  : status == 'ongoing'
                  ? 'No ongoing bookings.'
                  : 'No completed bookings.',
            ),
          );
        }

        final docs = [...raw]..sort((a, b) {
          final sa = a.data()['schedule']?['startAt'];
          final sb = b.data()['schedule']?['startAt'];
          final da = sa is Timestamp ? sa.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
          final db = sb is Timestamp ? sb.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
          return da.compareTo(db);
        });

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final d = docs[i];
            final m = d.data();

            final recName = (m['recipient']?['fullName'] ?? 'Care Recipient').toString();
            final cgName = (m['caregiverName'] ?? '').toString();

            final schedule = (m['schedule'] ?? {}) as Map<String, dynamic>;
            final st = schedule['startAt'] is Timestamp
                ? (schedule['startAt'] as Timestamp).toDate()
                : null;
            final en = schedule['endAt'] is Timestamp
                ? (schedule['endAt'] as Timestamp).toDate()
                : null;

            final dateStr = st != null
                ? '${st.year}-${st.month.toString().padLeft(2, '0')}-${st.day.toString().padLeft(2, '0')}'
                : '-';
            final timeStr = (st != null && en != null)
                ? '${st.hour.toString().padLeft(2, '0')}:${st.minute.toString().padLeft(2, '0')} – '
                '${en.hour.toString().padLeft(2, '0')}:${en.minute.toString().padLeft(2, '0')}'
                : '-';

            return Card(
              child: ListTile(
                title: Text(recName, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '$dateStr • $timeStr\n${cgName.isEmpty ? '' : 'Caregiver: $cgName'}',
                ),
                trailing: Text(status.toUpperCase()),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserBookingDetailPage(bookingId: d.id),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class UserBookingDetailPage extends StatelessWidget {
  final String bookingId;
  const UserBookingDetailPage({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('bookings').doc(bookingId);
    final updatesRef = FirebaseFirestore.instance
        .collection('bookings/$bookingId/journeyUpdates')
        .orderBy('at', descending: true);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snap.data!.exists) {
          return const Scaffold(body: Center(child: Text('Booking not found')));
        }
        final m = snap.data!.data()!;
        final status = (m['status'] ?? '').toString();

        final schedule = (m['schedule'] ?? {}) as Map<String, dynamic>;
        final st = schedule['startAt'] is Timestamp
            ? (schedule['startAt'] as Timestamp).toDate()
            : null;
        final en = schedule['endAt'] is Timestamp
            ? (schedule['endAt'] as Timestamp).toDate()
            : null;

        final dateStr = st != null
            ? '${st.year}-${st.month.toString().padLeft(2, '0')}-${st.day.toString().padLeft(2, '0')}'
            : '-';
        final timeStr = (st != null && en != null)
            ? '${st.hour.toString().padLeft(2, '0')}:${st.minute.toString().padLeft(2, '0')} – '
            '${en.hour.toString().padLeft(2, '0')}:${en.minute.toString().padLeft(2, '0')}'
            : '-';

        final rec = (m['recipient'] ?? {}) as Map<String, dynamic>;
        final cgName = (m['caregiverName'] ?? '').toString();
        final cgContact = (m['caregiverContact'] ?? '').toString();
        final notes = (m['notes'] ?? '').toString();
        final rate = (m['ratePerHour'] ?? 0).toString();
        final estHrs = (m['estimatedDurationHours'] ?? 0).toString();
        final total = (m['total'] ?? 0).toString();
        final liveLink = (m['liveLocationUrl'] ?? '').toString();

        final completion = (m['completion'] ?? {}) as Map<String, dynamic>;
        final result = (completion['result'] ?? '').toString();           // 'match' | 'additional' | ''
        final extra = (completion['suggestedExtra'] ?? 0).toString();

        return Scaffold(
          appBar: AppBar(title: Text('Booking • ${status.toUpperCase()}')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Booking ID: $bookingId', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Date: $dateStr'),
              Text('Time: $timeStr'),
              const Divider(height: 24),

              const Text('Details of Service Recipient', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              _kv('Full Name', rec['fullName']),
              _kv('Gender', rec['gender']),
              _kv('Contact Number', rec['contact']),
              _kv('Relationship', rec['relationship']),
              _kv('Age', rec['age']),
              _kv('House Address', rec['address']),
              const Divider(height: 24),

              const Text('Caregiver', style: TextStyle(fontWeight: FontWeight.w600)),
              _kv('Name', cgName.isEmpty ? '(assigned caregiver)' : cgName),
              _kv('Contact', cgContact.isEmpty ? '-' : cgContact),
              const SizedBox(height: 6),

              if (liveLink.isNotEmpty) _kv('Shared Live Location', liveLink),

              const SizedBox(height: 12),
              const Text('Status Timeline', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: updatesRef.snapshots(),
                builder: (context, us) {
                  final items = us.data?.docs ?? [];
                  if (items.isEmpty) return const Text('No updates yet.');
                  return Column(
                    children: items.map((d) {
                      final u = d.data();
                      final at = u['at'] is Timestamp ? (u['at'] as Timestamp).toDate() : null;
                      final when = at != null
                          ? '${at.year}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')} '
                          '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}'
                          : '-';
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.check_circle_outline),
                        title: Text(u['text'] ?? ''),
                        subtitle: Text(when),
                      );
                    }).toList(),
                  );
                },
              ),

              const Divider(height: 24),
              const Text('Payment Summary', style: TextStyle(fontWeight: FontWeight.w600)),
              _kv('Rate per Hour', 'RM $rate'),
              _kv('Estimated Duration', '${estHrs}h'),
              _kv('Total Payment', 'RM $total'),

              const SizedBox(height: 16),
              _actionForStatus(context, status, result, extra, bookingId, m),
              const SizedBox(height: 12),

              if (notes.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Additional Notes'),
                    const SizedBox(height: 4),
                    Text(notes),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _kv(String k, Object? v) =>
      ListTile(dense: true, title: Text(k), subtitle: Text((v ?? '-').toString()));

  Widget _actionForStatus(
      BuildContext context,
      String status,
      String result,
      String extra,
      String bookingId,
      Map<String, dynamic> booking,
      ) {
    if (status == 'upcoming') {
      return _pill(const Icon(Icons.verified, color: Colors.green), 'Booking Confirmed');
    }
    if (status == 'completed') {
      return _pill(const Icon(Icons.flag, color: Colors.teal), 'Completed — thank you!');
    }

    // ONGOING
    if (result == 'additional') {
      return _primaryButton(
        label: 'Make Additional Payment (RM $extra)',
        onTap: () {
          // TODO: navigate to your additional-payment page
          // Navigator.pushNamed(context, '/payment/additional', arguments: {...});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Additional Payment page not wired yet')),
          );
        },
      );
    }

    // result == '' or 'match' but not yet flipped to completed
    return _pill(const Icon(Icons.timer, color: Colors.orange), 'In progress');
  }

  Widget _primaryButton({required String label, required VoidCallback onTap}) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: ElevatedButton(onPressed: onTap, child: Text(label)),
    );
  }

  Widget _pill(Widget icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF7F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        icon,
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ]),
    );
  }
}
