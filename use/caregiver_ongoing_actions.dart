import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Put this widget on the caregiver booking detail page.
/// - If booking.status == upcoming -> shows Start
/// - If booking.status == ongoing -> shows Complete (records actual mins + suggested extra)
class CaregiverOngoingActions extends StatelessWidget {
  final String bookingId;
  const CaregiverOngoingActions({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('bookings').doc(bookingId);
    return StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(
      stream: ref.snapshots(),
      builder: (c, s) {
        if (!s.hasData) return const SizedBox.shrink();
        final m = s.data!.data()!;
        final status = (m['status'] ?? '').toString();
        final startedAt = m['startedAt'];
        final rate = (m['ratePerHour'] as num?)?.toDouble() ?? 0;

        return Column(
          children: [
            if (status == 'upcoming')
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    await ref.update({
                      'status': 'ongoing',
                      'startedAt': FieldValue.serverTimestamp(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    await FirebaseFirestore.instance
                        .collection('bookings/$bookingId/journeyUpdates')
                        .add({'text':'Caregiver started', 'at': FieldValue.serverTimestamp()});
                  },
                  child: const Text('Start'),
                ),
              ),
            if (status == 'ongoing')
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    final now = DateTime.now();
                    final start = startedAt is Timestamp ? startedAt.toDate() : now;
                    final mins = now.difference(start).inMinutes;

                    final result = mins <= 60 ? 'match' : 'additional';
                    final extraHours = ((mins - 60).clamp(0, 100000) / 60.0);
                    final extraAmount = extraHours > 0 ? double.parse((extraHours * rate).toStringAsFixed(2)) : 0.0;

                    await ref.update({
                      // stays ongoing
                      'completion': {
                        'result': result,
                        'actualMinutes': mins,
                        'suggestedExtra': result == 'additional' ? extraAmount : 0.0,
                      },
                      'updatedAt': FieldValue.serverTimestamp(),
                    });

                    await FirebaseFirestore.instance
                        .collection('bookings/$bookingId/journeyUpdates')
                        .add({'text':'Caregiver tapped Complete', 'at': FieldValue.serverTimestamp()});

                    if (c.mounted) {
                      ScaffoldMessenger.of(c).showSnackBar(
                        const SnackBar(content: Text('Completion recorded. User will finalize payment.')),
                      );
                    }
                  },
                  child: const Text('Complete'),
                ),
              ),
          ],
        );
      },
    );
  }
}
