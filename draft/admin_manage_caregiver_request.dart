// lib/admin_manage_caregiver_request.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';

/// If Firestore stored a full https URL → use refFromURL.
/// If Firestore stored a path (e.g. caregivers/uid/.../file.jpg) → use ref(path).
Future<Uri?> _freshDownloadUri(String rawOrPath) async {
  try {
    final s = rawOrPath.replaceAll('"', '').trim();
    final Reference ref =
    s.startsWith('http') ? FirebaseStorage.instance.refFromURL(s)
        : FirebaseStorage.instance.ref(s);
    final url = await ref.getDownloadURL(); // correct host + fresh token
    return Uri.parse(url);
  } catch (_) {
    return null;
  }
}

/// Universal external opener (web/mobile). Tries the string directly, then
/// falls back to a fresh Storage URL if needed.
Future<void> _openExternal(BuildContext context, String rawOrPath) async {
  // A) try opening the provided string directly
  try {
    final direct = Uri.parse(rawOrPath.replaceAll('"', '').trim());
    if (direct.hasScheme && await canLaunchUrl(direct)) {
      final ok = await launchUrl(
        direct,
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_blank',
      );
      if (ok) return;
    }
  } catch (_) {/* continue */}

  // B) get a fresh signed URL from Storage
  final fresh = await _freshDownloadUri(rawOrPath);
  if (fresh != null && await canLaunchUrl(fresh)) {
    final ok = await launchUrl(
      fresh,
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_blank',
    );
    if (ok) return;
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open image link')),
    );
  }
}

/* =========================== PAGE ============================ */

class AdminManageCaregiver extends StatefulWidget {
  final String uid;
  const AdminManageCaregiver({super.key, required this.uid});

  @override
  State<AdminManageCaregiver> createState() => _AdminManageCaregiverState();
}

class _AdminManageCaregiverState extends State<AdminManageCaregiver> {
  bool _busy = false;

  /* ----------- helpers on the State (defined BEFORE build) ----------- */

  Future<void> _setBusy(bool v) async => setState(() => _busy = v);

  Future<String?> _askReason(BuildContext context) async {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rejection reason'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Tell the caregiver why the request is rejected',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('OK')),
        ],
      ),
    );
  }

  /// Unified success notice after Approve/Reject.
  Future<void> _notifyAction({
    required BuildContext context,
    required String title,
    required String message,
    required IconData icon,
    Color? iconColor,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        icon: Icon(icon, color: iconColor ?? Colors.teal, size: 32),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  /* ------------------------------- build ------------------------------ */

  @override
  Widget build(BuildContext context) {
    final docRef = FirebaseFirestore.instance.doc('caregivers/${widget.uid}');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: const Text('Manage Caregiver'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: docRef.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const LinearProgressIndicator();
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('Record not found.'));
          }

          final m = snap.data!.data() as Map<String, dynamic>;
          final status = (m['status'] ?? 'pending') as String;

          // attachments as saved
          final attachments = (m['attachments'] ?? {}) as Map<String, dynamic>;
          final certs = List<String>.from(attachments['certificates'] ?? const <String>[]);
          final dls   = List<String>.from(attachments['drivingLicenses'] ?? const <String>[]);
          final ics   = List<String>.from(attachments['idCards'] ?? const <String>[]);
          final pic   = attachments['profilePic'] as String?;

          return AbsorbPointer(
            absorbing: _busy,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // top row: id & status
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'ID: ${widget.uid}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    _StatusChip(status: status),
                  ],
                ),
                const SizedBox(height: 12),

                // avatar (click to open image link)
                Center(child: _SmartAvatar(url: pic, radius: 56)),
                const SizedBox(height: 16),

                // identity
                _LabeledField(label: 'Full Name', value: '${m['fullName'] ?? ''}'),
                _LabeledField(label: 'Email Address', value: '${m['email'] ?? ''}'),
                _LabeledField(label: 'Contact Number', value: '${m['contact'] ?? ''}'),
                const SizedBox(height: 8),

                // attachments (links only)
                _UrlsSection(title: 'Certificate / License (max 3)', urls: certs),
                _UrlsSection(title: 'Driving License (max 3)', urls: dls),
                _UrlsSection(title: 'IC (front & back) (max 3)', urls: ics),
                const SizedBox(height: 12),

                // details
                _LabeledField(label: 'Rate per Hour (RM)', value: _fmtMoney(m['ratePerHour'])),
                _LabeledField(label: 'Years of Experience', value: '${m['yearsOfExperience'] ?? ''}'),
                _LabeledField(label: 'Select Region in Penang', value: '${m['region'] ?? ''}'),
                _LabeledField(label: 'Select Your Preferred Language', value: '${m['language'] ?? ''}'),
                _LabeledField(label: 'Select Your Gender', value: '${m['gender'] ?? ''}'),
                const SizedBox(height: 12),

                Text(
                  'Select Available Schedule:',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                _AvailabilityTable(availability: Map<String, dynamic>.from(m['availability'] ?? {})),
                const SizedBox(height: 16),

                // actions
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close),
                      label: const Text('Reject'),
                      onPressed: (status == 'approved' || status == 'rejected' || _busy)
                          ? null
                          : () async {
                        final reason = await _askReason(context);
                        if (reason == null || reason.isEmpty) return;

                        await _setBusy(true);
                        try {
                          await docRef.update({
                            'status': 'rejected',
                            'rejectionReason': reason,
                            'approvedAt': null,
                            'approvedBy': null,
                          });

                          if (!mounted) return;
                          await _notifyAction(
                            context: context,
                            title: 'Request Rejected',
                            message: 'You have rejected this caregiver.\nReason: $reason',
                            icon: Icons.cancel_rounded,
                            iconColor: Colors.red,
                          );

                          if (context.mounted) Navigator.pop(context);
                        } finally {
                          if (mounted) await _setBusy(false);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('Approve'),
                      onPressed: (status == 'approved' || _busy)
                          ? null
                          : () async {
                        await _setBusy(true);
                        try {
                          await docRef.update({
                            'status': 'approved',
                            'approvedAt': FieldValue.serverTimestamp(),
                            'approvedBy': 'admin', // replace with admin uid if you track it
                            'rejectionReason': null,
                          });

                          if (!mounted) return;
                          await _notifyAction(
                            context: context,
                            title: 'Request Approved',
                            message: 'The caregiver has been approved successfully.',
                            icon: Icons.check_circle_rounded,
                            iconColor: Colors.green,
                          );

                          if (context.mounted) Navigator.pop(context);
                        } finally {
                          if (mounted) await _setBusy(false);
                        }
                      },
                    ),
                  ),
                ]),
                if (_busy) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/* ---------------- helpers & small widgets ---------------- */

class _LabeledField extends StatelessWidget {
  final String label;
  final String value;
  const _LabeledField({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextField(
          readOnly: true,
          controller: TextEditingController(text: value),
          decoration: const InputDecoration(),
        ),
      ]),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});
  @override
  Widget build(BuildContext context) {
    Color bg;
    switch (status) {
      case 'approved':
        bg = Colors.green.shade100;
        break;
      case 'rejected':
        bg = Colors.red.shade100;
        break;
      default:
        bg = Colors.orange.shade100; // pending
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Text(status.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _UrlsSection extends StatelessWidget {
  final String title;
  final List<String> urls;
  const _UrlsSection({required this.title, required this.urls});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (urls.isEmpty)
              const Text('None uploaded')
            else
              ...urls.map((raw) {
                final display = raw.replaceAll('"', '').trim();
                String fileName = '';
                try {
                  final i = display.indexOf('/o/');
                  final j = display.indexOf('?', i >= 0 ? i : 0);
                  final encPath = (i >= 0)
                      ? display.substring(i + 3, j >= 0 ? j : display.length)
                      : display;
                  fileName = Uri.decodeComponent(encPath.split('/').last);
                } catch (_) {}

                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.link),
                  title: Text(
                    fileName.isEmpty ? 'Attachment' : fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(display, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: TextButton.icon(
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Open'),
                    onPressed: () => _openExternal(context, raw),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _SmartAvatar extends StatelessWidget {
  final String? url;
  final double radius;
  const _SmartAvatar({required this.url, required this.radius});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.trim().isEmpty) {
      return CircleAvatar(radius: radius, child: const Icon(Icons.person, size: 56));
    }
    return InkWell(
      borderRadius: BorderRadius.circular(radius),
      onTap: () => _openExternal(context, url!),
      child: CircleAvatar(radius: radius, child: const Icon(Icons.open_in_new)),
    );
  }
}

class _AvailabilityTable extends StatelessWidget {
  final Map<String, dynamic> availability;
  const _AvailabilityTable({required this.availability});
  @override
  Widget build(BuildContext context) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    TableRow _row(String d) {
      final item = Map<String, dynamic>.from(availability[d] ?? {});
      final start = (item['start'] ?? '') as String;
      final end = (item['end'] ?? '') as String;
      return TableRow(children: [
        Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(d)),
        Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: _Pill(text: start.isEmpty ? '-' : start)),
        Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: _Pill(text: end.isEmpty ? '-' : end)),
      ]);
    }

    final rows = <TableRow>[
      const TableRow(children: [
        Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Day', style: TextStyle(fontWeight: FontWeight.w700))),
        Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Start Time', style: TextStyle(fontWeight: FontWeight.w700))),
        Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('End Time', style: TextStyle(fontWeight: FontWeight.w700))),
      ]),
      ...days.map(_row),
    ];

    return Table(
      columnWidths: const {0: FixedColumnWidth(110)},
      border: const TableBorder.symmetric(inside: BorderSide(color: Colors.grey)),
      children: rows,
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black26),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text),
    );
  }
}

String _fmtMoney(dynamic v) {
  final n = (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0.0;
  return n == 0 ? '' : n.toStringAsFixed(2);
}
