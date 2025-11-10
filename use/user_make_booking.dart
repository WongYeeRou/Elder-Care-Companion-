import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class UserMakeBookingPage extends StatefulWidget {
  static const route = '/user/make-booking';
  const UserMakeBookingPage({super.key});

  @override
  State<UserMakeBookingPage> createState() => _UserMakeBookingPageState();
}

class _UserMakeBookingPageState extends State<UserMakeBookingPage> {
  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();
  final _formKey3 = GlobalKey<FormState>();

  // client (auto-filled)
  final _clientName = TextEditingController();
  final _clientEmail = TextEditingController();
  final _clientContact = TextEditingController();

  // recipient
  final _recName = TextEditingController();
  String _recGender = 'Male';
  final _recContact = TextEditingController();
  final _recRel = TextEditingController();
  final _recAge = TextEditingController();
  final _recAddr = TextEditingController();

  // checkup
  final _checkupType = TextEditingController();
  final _clinicAddr = TextEditingController();

  // schedule
  DateTime? _date;
  TimeOfDay? _time;

  // misc
  final _notes = TextEditingController();

  Map<String, dynamic>? _caregiver;
  String? _caregiverId;

  @override
  void initState() {
    super.initState();
    _prefillClient();
  }

  Future<void> _prefillClient() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final d = snap.data();
      if (d != null) {
        _clientName.text = (d['username'] ?? d['name'] ?? d['fullName'] ?? '').toString();
        _clientEmail.text = (d['email'] ?? '').toString();
        _clientContact.text =
            (d['contact'] ?? d['phone'] ?? d['contactNumber'] ?? '').toString();
        if (mounted) setState(() {});
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final c in [
      _clientName, _clientEmail, _clientContact, _recName, _recContact, _recRel,
      _recAge, _recAddr, _checkupType, _clinicAddr, _notes
    ]) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map?;
    if (args == null) {
      return const Scaffold(body: Center(child: Text('Missing caregiver data')));
    }
    _caregiverId = args['caregiverId'] as String;
    _caregiver = Map<String, dynamic>.from(args['caregiver'] as Map);
    final ratePerHour = (_caregiver!['ratePerHour'] as num).toDouble();

    final df = DateFormat('yyyy-MM-dd');

    return Scaffold(
      appBar: AppBar(title: const Text('Booking')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // ----------- Client Details -----------
          Form(
            key: _formKey1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Details of Client', style: TextStyle(fontWeight: FontWeight.bold)),
                TextFormField(controller: _clientName, decoration: const InputDecoration(labelText: 'Name'), validator: _req),
                TextFormField(controller: _clientEmail, decoration: const InputDecoration(labelText: 'Email Address'), validator: _req),
                TextFormField(controller: _clientContact, decoration: const InputDecoration(labelText: 'Contact'), validator: _req),
                const SizedBox(height: 12),

                const Text('Details of Service Recipient', style: TextStyle(fontWeight: FontWeight.bold)),
                TextFormField(controller: _recName, decoration: const InputDecoration(labelText: 'Full Name (as per NRIC)'), validator: _req),

                DropdownButtonFormField<String>(
                  value: _recGender,
                  items: const [
                    DropdownMenuItem(value: 'Male', child: Text('Male')),
                    DropdownMenuItem(value: 'Female', child: Text('Female')),
                  ],
                  onChanged: (v) => setState(() => _recGender = v ?? 'Male'),
                  decoration: const InputDecoration(labelText: 'Gender'),
                ),
                TextFormField(controller: _recContact, decoration: const InputDecoration(labelText: 'Contact Number'), validator: _req),
                TextFormField(controller: _recRel, decoration: const InputDecoration(labelText: 'Relationship'), validator: _req),
                TextFormField(controller: _recAge, decoration: const InputDecoration(labelText: 'Age'), validator: _req),
                TextFormField(controller: _recAddr, decoration: const InputDecoration(labelText: 'House Address'), validator: _req),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ----------- Check-up Info + Schedule -----------
          Form(
            key: _formKey2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(controller: _checkupType, decoration: const InputDecoration(labelText: 'Check-Up Type'), validator: _req),
                TextFormField(controller: _clinicAddr, decoration: const InputDecoration(labelText: 'Hospital / Clinic Address'), validator: _req),
                const SizedBox(height: 8),

                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: now,
                          lastDate: now.add(const Duration(days: 365)),
                          initialDate: _date ?? now,
                        );
                        if (picked != null) setState(() => _date = picked);
                      },
                      child: Text(_date == null ? 'Select Date' : df.format(_date!)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
                        );
                        if (picked != null) setState(() => _time = picked);
                      },
                      child: Text(_time == null ? 'Select Time' : _time!.format(context)),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),

                // FIXED 1 HOUR (read-only)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.teal.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('Estimated Duration (fixed)'),
                      Text('1 hour', style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ----------- Notes + Summary -----------
          Form(
            key: _formKey3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Additional Notes (optional)')),
                const SizedBox(height: 8),
                _summaryCard(ratePerHour),
              ],
            ),
          ),
          const SizedBox(height: 16),

          ElevatedButton(
            onPressed: () async {
              if (!_formKey1.currentState!.validate() || !_formKey2.currentState!.validate()) return;
              if (_date == null || _time == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select date & time')));
                return;
              }

              final start = DateTime(_date!.year, _date!.month, _date!.day, _time!.hour, _time!.minute);
              final end = start.add(const Duration(hours: 1));

              final ok = _isWithinCaregiverAvailability(
                caregiver: _caregiver!,
                start: start,
                durationHours: 1,
              );
              if (!ok) {
                _showAvailabilityDialog(context, _caregiver!['availability'] as Map<String, dynamic>?);
                return;
              }

              final uid = FirebaseAuth.instance.currentUser!.uid;
              final reqRef = FirebaseFirestore.instance.collection('bookingRequests').doc();
              await reqRef.set({
                'userUid': uid,
                'caregiverUid': _caregiverId,
                'client': {
                  'name': _clientName.text.trim(),
                  'email': _clientEmail.text.trim(),
                  'contact': _clientContact.text.trim(),
                },
                'recipient': {
                  'fullName': _recName.text.trim(),
                  'gender': _recGender,
                  'contact': _recContact.text.trim(),
                  'relationship': _recRel.text.trim(),
                  'age': _recAge.text.trim(),
                  'address': _recAddr.text.trim(),
                },
                'checkupType': _checkupType.text.trim(),
                'clinicAddress': _clinicAddr.text.trim(),
                'startAt': Timestamp.fromDate(start),
                'endAt': Timestamp.fromDate(end),
                'estDurationHours': 1.0,
                'ratePerHour': ratePerHour,
                'estTotal': double.parse(ratePerHour.toStringAsFixed(2)), // 1h
                'notes': _notes.text.trim(),
                'status': 'awaiting_payment',
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              });

              if (!mounted) return;
              Navigator.pushNamed(context, '/payment/cash-in', arguments: {
                'requestId': reqRef.id,
                'estTotal': ratePerHour,
              });
            },
            child: const Text('Proceed to Payment'),
          ),
        ]),
      ),
    );
  }

  Widget _summaryCard(double ratePerHour) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.teal.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Payment Summary:', style: TextStyle(fontWeight: FontWeight.bold)),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Rate per Hour'), Text('RM ${ratePerHour.toStringAsFixed(2)}'),
          ]),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [
            Text('Estimated Duration'), Text('1 h'),
          ]),
          const Divider(),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Total Payment', style: TextStyle(fontWeight: FontWeight.w600)),
            Text('RM ${ratePerHour.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ],
      ),
    );
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  static final _weekdayNames = const [
    'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'
  ];

  bool _isWithinCaregiverAvailability({
    required Map<String, dynamic> caregiver,
    required DateTime start,
    required int durationHours,
  }) {
    final availability = caregiver['availability'] as Map<String, dynamic>?;
    if (availability == null || availability.isEmpty) return false;

    final dayName = _weekdayNames[start.weekday - 1];
    final slot = availability[dayName];
    if (slot is! Map) return false;

    final st = (slot['start'] ?? '') as String? ?? '';
    final en = (slot['end'] ?? '') as String? ?? '';
    if (st.isEmpty || en.isEmpty) return false;

    final startMin = _hmToMinutes(st);
    final endMin = _hmToMinutes(en);
    final userStartMin = start.hour * 60 + start.minute;
    final userEndMin = userStartMin + durationHours * 60;

    return userStartMin >= startMin && userEndMin <= endMin;
  }

  static int _hmToMinutes(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return h * 60 + m;
  }

  void _showAvailabilityDialog(BuildContext context, Map<String, dynamic>? availability) {
    final rows = <String>[];
    if (availability != null && availability.isNotEmpty) {
      for (final day in _weekdayNames) {
        final slot = availability[day];
        if (slot is Map && (slot['start'] ?? '') != '' && (slot['end'] ?? '') != '') {
          rows.add('$day: ${slot['start']} - ${slot['end']}');
        }
      }
    }
    final msg = rows.isEmpty
        ? 'This caregiver has no working hours set.'
        : rows.join('\n');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Selected time is not available'),
        content: SingleChildScrollView(
          child: Text('Working day & time for this caregiver:\n\n$msg'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }
}
