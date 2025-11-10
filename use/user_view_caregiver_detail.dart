// lib/user_view_caregiver_detail.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// Booking form screen (make sure this file exists and route is registered)
import 'user_make_booking.dart';

class CaregiverDetailArgs {
  final String caregiverId;
  const CaregiverDetailArgs({required this.caregiverId});
}

class CaregiverDetailPage extends StatelessWidget {
  static const route = '/caregiver/detail';
  const CaregiverDetailPage({super.key});

  static const Color mint = Color(0xFF33C7B6);

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as CaregiverDetailArgs?;
    final id = args?.caregiverId;

    if (id == null) {
      return const _ScaffoldCentered(Text('Missing caregiverId.'));
    }

    final docRef = FirebaseFirestore.instance.collection('caregivers').doc(id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Back'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: docRef.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const _ScaffoldCentered(CircularProgressIndicator());
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const _ScaffoldCentered(Text('Caregiver not found.'));
          }

          final data = snap.data!.data()!;
          final name = (data['fullName'] ?? '') as String;
          final gender = (data['gender'] ?? '') as String? ?? '';
          final years = (data['yearsOfExperience'] ?? 0).toString();
          final region = (data['region'] ?? '') as String? ?? '';
          final language = (data['language'] ?? '') as String? ?? '';
          final rate = (data['ratePerHour'] ?? 0).toString();
          final profile = (data['attachments']?['profilePic'] ?? '') as String? ?? '';
          final status = (data['status'] ?? '') as String? ?? '';
          final availability = (data['availability'] ?? {}) as Map<String, dynamic>;
          final isVerified = status == 'approved';

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            child: Column(
              children: [
                // LEFT CARD
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: mint.withValues(alpha: .35)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundImage:
                              profile.isNotEmpty ? NetworkImage(profile) : null,
                              child: profile.isEmpty
                                  ? const Icon(Icons.person, size: 36)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          name.isEmpty ? 'Caregiver' : name,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isVerified)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: mint.withValues(alpha: .15),
                                            borderRadius:
                                            const BorderRadius.all(Radius.circular(8)),
                                            border: Border.all(color: mint, width: 1),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.verified, size: 16),
                                              SizedBox(width: 4),
                                              Text('Verified'),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  _infoLine('Gender', gender),
                                  _infoLine('Years of Experience', years),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Divider(height: 20),
                        _inputLook('Preferred Region in Penang', region),
                        const SizedBox(height: 10),
                        _inputLook('Preferred Language', language),
                        const SizedBox(height: 16),
                        Text(
                          'Available Days and Time Slots:',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _AvailabilityTable(availability: availability),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // RIGHT CARD
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: mint.withValues(alpha: .35)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ...inside the RIGHT CARD Column children: [
                        const Text(
                          'Rate per Hour',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        _inputLook('RM…', rate, readOnly: true),
                        const SizedBox(height: 16),

// ❌ ratings removed

// BOOK BUTTON
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: mint,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(46),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                UserMakeBookingPage.route,
                                arguments: {'caregiverId': id, 'caregiver': data},
                              );
                            },
                            child: const Text('Book'),
                          ),
                        ),

                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static Widget _infoLine(String label, String value) {
    return Text(
      value.isEmpty ? label : '$label · $value',
      style: const TextStyle(color: Colors.black54),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  static Widget _inputLook(String label, String value, {bool readOnly = true}) {
    return TextField(
      controller: TextEditingController(text: value),
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  static Widget _commentTile(String text) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          side: const BorderSide(width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _AvailabilityTable extends StatelessWidget {
  final Map<String, dynamic> availability;
  const _AvailabilityTable({required this.availability});

  static const rows = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];

  @override
  Widget build(BuildContext context) {
    final border = TableBorder.all(color: Colors.black12);

    final List<TableRow> tableRows = [];
    for (final day in rows) {
      final slot = availability[day];
      String text = '—';
      if (slot is Map) {
        final st = (slot['start'] ?? '') as String? ?? '';
        final en = (slot['end'] ?? '') as String? ?? '';
        if (st.isNotEmpty && en.isNotEmpty) text = '$st - $en';
      }
      tableRows.add(
        TableRow(children: [
          _cell('Day: $day'),
          _cell(text),
        ]),
      );
    }

    return Table(
      border: border,
      columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(3)},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(children: [
          _cell('Day', bold: true),
          _cell('Time', bold: true),
        ]),
        ...tableRows,
      ],
    );
  }

  static const _pad = EdgeInsets.symmetric(horizontal: 12, vertical: 10);
  static const TextStyle _bold = TextStyle(fontWeight: FontWeight.w700);
  static const TextStyle _reg = TextStyle();

  static Widget _cell(String t, {bool bold = false}) {
    return Padding(
      padding: _pad,
      child: Text(
        t.startsWith('Day: ') ? t.substring(5) : t,
        style: bold ? _bold : _reg,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _ScaffoldCentered extends StatelessWidget {
  final Widget child;
  const _ScaffoldCentered(this.child);

  @override
  Widget build(BuildContext context) => Center(child: child);
}
