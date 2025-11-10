import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CaregiverBookingsPage extends StatelessWidget {
  const CaregiverBookingsPage({super.key});

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
            _CaregiverBookingList(status: 'upcoming'),
            _CaregiverBookingList(status: 'ongoing'),
            _CaregiverBookingList(status: 'completed'),
          ],
        ),
      ),
    );
  }
}

class _CaregiverBookingList extends StatelessWidget {
  final String status;
  const _CaregiverBookingList({required this.status});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Please sign in.'));

    final q = FirebaseFirestore.instance
        .collection('bookings')
        .where('caregiverId', isEqualTo: uid)
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

            final recip = (m['recipient']?['fullName'] ?? 'Care Recipient').toString();
            final client = (m['client']?['name'] ?? m['userId']).toString();

            final schedule = (m['schedule'] ?? {}) as Map<String, dynamic>;
            final st = schedule['startAt'] is Timestamp ? (schedule['startAt'] as Timestamp).toDate() : null;
            final en = schedule['endAt'] is Timestamp ? (schedule['endAt'] as Timestamp).toDate() : null;
            final dateStr = st != null
                ? '${st.year}-${st.month.toString().padLeft(2, '0')}-${st.day.toString().padLeft(2, '0')}'
                : '-';
            final timeStr = (st != null && en != null)
                ? '${st.hour.toString().padLeft(2, '0')}:${st.minute.toString().padLeft(2, '0')} – '
                '${en.hour.toString().padLeft(2, '0')}:${en.minute.toString().padLeft(2, '0')}'
                : '-';

            return Card(
              child: ListTile(
                title: Text(recip, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('$dateStr • $timeStr\nClient: $client'),
                trailing: Text(status.toUpperCase()),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CaregiverBookingDetailPage(bookingId: d.id),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class CaregiverBookingDetailPage extends StatefulWidget {
  final String bookingId;
  const CaregiverBookingDetailPage({super.key, required this.bookingId});

  @override
  State<CaregiverBookingDetailPage> createState() => _CaregiverBookingDetailPageState();
}

class _CaregiverBookingDetailPageState extends State<CaregiverBookingDetailPage> {
  final _statusCtrl = TextEditingController();
  final _liveCtrl = TextEditingController();

  @override
  void dispose() {
    _statusCtrl.dispose();
    _liveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('bookings').doc(widget.bookingId);
    final updatesRef = ref.collection('journeyUpdates').orderBy('at', descending: true);

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
        final st = schedule['startAt'] is Timestamp ? (schedule['startAt'] as Timestamp).toDate() : null;
        final en = schedule['endAt'] is Timestamp ? (schedule['endAt'] as Timestamp).toDate() : null;
        final dateStr = st != null
            ? '${st.year}-${st.month.toString().padLeft(2, '0')}-${st.day.toString().padLeft(2, '0')}'
            : '-';
        final timeStr = (st != null && en != null)
            ? '${st.hour.toString().padLeft(2, '0')}:${st.minute.toString().padLeft(2, '0')} – '
            '${en.hour.toString().padLeft(2, '0')}:${en.minute.toString().padLeft(2, '0')}'
            : '-';

        final client = (m['client'] ?? {}) as Map<String, dynamic>;
        final recip = (m['recipient'] ?? {}) as Map<String, dynamic>;

        // Fallbacks in case admin didn’t copy fields when creating bookings
        final checkupType = (m['checkupType'] ??
            (m['request'] is Map ? (m['request']['checkupType'] ?? '') : '')).toString();
        final clinicAddr = (m['clinicAddress'] ??
            (m['request'] is Map ? (m['request']['clinicAddress'] ?? '') : '')).toString();

        final rate = (m['ratePerHour'] ?? 0).toDouble();
        final estHours = (m['estimatedDurationHours'] ?? 1).toDouble();

        return Scaffold(
          appBar: AppBar(title: Text('Booking • ${status.toUpperCase()}')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Booking ID: ${widget.bookingId}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Date: $dateStr'),
              Text('Time: $timeStr'),
              const Divider(height: 24),

              const Text('Details of Client', style: TextStyle(fontWeight: FontWeight.w600)),
              _kv('Name', client['name']),
              _kv('Email Address', client['email']),
              _kv('Contact', client['contact']),
              const SizedBox(height: 8),

              const Text('Details of Service Recipient', style: TextStyle(fontWeight: FontWeight.w600)),
              _kv('Name', recip['fullName']),
              _kv('Gender', recip['gender']),
              _kv('Contact Number', recip['contact']),
              _kv('Relationship', recip['relationship']),
              _kv('Age', recip['age']),
              _kv('House Address', recip['address']),
              const SizedBox(height: 8),

              _kv('Check-Up Type', checkupType),
              _kv('Hospital / Clinic Address', clinicAddr),
              const SizedBox(height: 8),

              const Text('Payment', style: TextStyle(fontWeight: FontWeight.w600)),
              _kv('Duration (prepaid)', '${estHours.toStringAsFixed(0)} h'),
              _kv('Rate per Hour', 'RM ${rate.toStringAsFixed(2)}'),
              const Divider(height: 24),

              if (status == 'upcoming')
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      // Confirm before start
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Start now?'),
                          content: const Text('This will set the job to ONGOING.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Start'),
                            ),
                          ],
                        ),
                      );
                      if (ok != true) return;

                      await ref.update({
                        'status': 'ongoing',
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                      await ref.collection('journeyUpdates').add({
                        'text': 'Caregiver started job',
                        'at': FieldValue.serverTimestamp(),
                      });
                      if (mounted) Navigator.pop(context);
                    },
                    child: const Text('Start'),
                  ),
                ),

              if (status == 'ongoing') ...[
                const Text('Updated Status', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _statusCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Status text',
                          hintText: 'e.g., Picked up recipient',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final t = _statusCtrl.text.trim();
                        if (t.isEmpty) return;
                        await FirebaseFirestore.instance
                            .collection('bookings')
                            .doc(widget.bookingId)
                            .collection('journeyUpdates')
                            .add({'text': t, 'at': FieldValue.serverTimestamp()});
                        _statusCtrl.clear();
                      },
                      child: const Text('Send'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _liveCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Share live location link',
                          hintText: 'Paste a URL (Google Maps share, etc.)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        await ref.update({
                          'liveLocationUrl': _liveCtrl.text.trim(),
                          'updatedAt': FieldValue.serverTimestamp(),
                        });
                        _liveCtrl.clear();
                      },
                      child: const Text('Send'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      // NO RETRIEVE — only “match” or “additional”
                      final now = DateTime.now();
                      final actualMin = st == null
                          ? 60
                          : now.difference(st).inMinutes.clamp(0, 24 * 60);

                      final prepaidHours = (estHours <= 0 ? 1 : estHours).round();
                      final prepaidMin = prepaidHours * 60;

                      String result = 'match';
                      double suggestedExtra = 0.0;
                      if (actualMin > prepaidMin) {
                        final totalHours = (actualMin / 60).ceil();
                        final extraHours = totalHours - prepaidHours;
                        suggestedExtra =
                            double.parse((extraHours * rate).toStringAsFixed(2));
                        result = 'additional';
                      }

                      final updates = <String, dynamic>{
                        'completion': {
                          'actualDurationMinutes': actualMin,
                          'result': result,                 // 'match' | 'additional'
                          'suggestedExtra': suggestedExtra, // RM
                          'completedByCaregiverAt': FieldValue.serverTimestamp(),
                        },
                        'updatedAt': FieldValue.serverTimestamp(),
                      };
                      // If no extra needed → complete immediately; else keep ongoing
                      if (result == 'match') updates['status'] = 'completed';

                      await ref.update(updates);

                      await ref.collection('journeyUpdates').add({
                        'text': result == 'match'
                            ? 'Caregiver completed the job (no extra payment)'
                            : 'Caregiver completed the job (awaiting additional payment by user)',
                        'at': FieldValue.serverTimestamp(),
                      });

                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              result == 'match'
                                  ? 'Marked as Completed.'
                                  : 'Additional payment required by user.',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('Complete'),
                  ),
                ),
              ],

              const SizedBox(height: 16),
              const Text('Timeline', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),

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
            ],
          ),
        );
      },
    );
  }

  Widget _kv(String k, Object? v) => ListTile(
    dense: true,
    title: Text(k),
    subtitle: Text((v ?? '-').toString()),
  );
}
