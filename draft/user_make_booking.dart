// lib/user_make_booking.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MakeBookingArgs {
  final String caregiverId;
  final Map<String, dynamic>? caregiverData;
  const MakeBookingArgs({required this.caregiverId, this.caregiverData});
}

class MakeBookingPage extends StatefulWidget {
  static const route = '/booking/make';
  const MakeBookingPage({super.key});

  @override
  State<MakeBookingPage> createState() => _MakeBookingPageState();
}

class _MakeBookingPageState extends State<MakeBookingPage> {
  static const Color mint = Color(0xFF33C7B6);

  // ---------- client (user) ----------
  final _clientName = TextEditingController();
  final _clientEmail = TextEditingController();
  final _clientContact = TextEditingController();

  // ---------- service recipient ----------
  final _recName = TextEditingController();
  final _recSalutation = TextEditingController();
  String? _recGender;
  final _recContact = TextEditingController();
  final _recRelationship = TextEditingController();
  final _recAge = TextEditingController();
  final _recAddress = TextEditingController();

  // ---------- booking ----------
  final _checkupType = TextEditingController();
  final _clinicAddress = TextEditingController();
  final _notes = TextEditingController();

  DateTime? _date;
  TimeOfDay? _time;
  double _estimatedHours = 2.0; // min booking is 2 hours (double)
  num _ratePerHour = 0;

  Map<String, dynamic> _availability = {};
  late final String _caregiverId;

  bool _loadingUser = true;
  bool _loadingCaregiver = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as MakeBookingArgs;
    _caregiverId = args.caregiverId;

    _loadCurrentUserProfile();

    if (args.caregiverData != null) {
      _applyCaregiverDoc(args.caregiverData!);
      _loadingCaregiver = false;
    } else {
      FirebaseFirestore.instance
          .collection('caregivers')
          .doc(_caregiverId)
          .get()
          .then((d) {
        if (d.exists) _applyCaregiverDoc(d.data()!);
      }).whenComplete(() => setState(() => _loadingCaregiver = false));
    }
  }

  void _applyCaregiverDoc(Map<String, dynamic> data) {
    final r = data['ratePerHour'];
    if (r is num) _ratePerHour = r;
    final av = data['availability'];
    if (av is Map<String, dynamic>) _availability = av;
  }

  Future<void> _loadCurrentUserProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loadingUser = false);
      return;
    }
    try {
      final doc =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data();
      if (data != null) {
        _clientName.text = (data['username'] ?? '').toString();
        _clientEmail.text = (data['email'] ?? '').toString();
        _clientContact.text = (data['contact'] ?? '').toString(); // auto-fill
      }
    } finally {
      if (mounted) setState(() => _loadingUser = false);
    }
  }

  @override
  void dispose() {
    _clientName.dispose();
    _clientEmail.dispose();
    _clientContact.dispose();
    _recName.dispose();
    _recSalutation.dispose();
    _recContact.dispose();
    _recRelationship.dispose();
    _recAge.dispose();
    _recAddress.dispose();
    _checkupType.dispose();
    _clinicAddress.dispose();
    _notes.dispose();
    super.dispose();
  }

  // ------------------- availability helpers -------------------
  static DateTime? _parseHHmm(String? v) {
    if (v == null) return null;
    final p = v.split(':');
    if (p.length != 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return DateTime(0, 1, 1, h, m);
  }

  bool _isWithinAvailability(DateTime dt) {
    if (_availability.isEmpty) return true;
    final weekday = const [
      'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'
    ][dt.weekday - 1];

    final slot = _availability[weekday];
    if (slot is! Map) return false;

    final st = _parseHHmm(slot['start'] as String?);
    final en = _parseHHmm(slot['end'] as String?);
    if (st == null || en == null) return false;

    final t = DateTime(0, 1, 1, dt.hour, dt.minute);
    return t.isAfter(st) && t.isBefore(en);
  }

  String _availabilityLabel() {
    final parts = <String>[];
    for (final day in const [
      'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'
    ]) {
      final m = _availability[day];
      if (m is Map) {
        final s = (m['start'] ?? '').toString();
        final e = (m['end'] ?? '').toString();
        if (s.isNotEmpty && e.isNotEmpty) parts.add('$day $s–$e');
      }
    }
    return parts.isEmpty ? '—' : parts.join(' · ');
  }

  // ----------- robust pickers -----------
  Future<void> _pickDate() async {
    final now = DateTime.now();
    DateTime? picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: _date ?? now,
    );

    // Fallback dialog if null (rare on some web configs)
    picked ??= await showDialog<DateTime>(
      context: context,
      builder: (_) {
        DateTime tmp = _date ?? now;
        return AlertDialog(
          title: const Text('Select date'),
          content: SizedBox(
            width: 320,
            height: 320,
            child: CalendarDatePicker(
              firstDate: now,
              lastDate: now.add(const Duration(days: 365)),
              initialDate: _date ?? now,
              onDateChanged: (d) => tmp = d,
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, tmp), child: const Text('OK')),
          ],
        );
      },
    );

    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
    );

    picked ??= await showDialog<TimeOfDay>(
      context: context,
      builder: (_) => TimePickerDialog(
        initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
      ),
    );

    if (picked != null) setState(() => _time = picked);
  }

  // ------------------- save -------------------
  Future<void> _saveAndProceed() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in.')),
      );
      return;
    }

    if (_clientName.text.trim().isEmpty ||
        _clientEmail.text.trim().isEmpty ||
        _clientContact.text.trim().isEmpty ||
        _recName.text.trim().isEmpty ||
        _recGender == null ||
        _clinicAddress.text.trim().isEmpty ||
        _date == null || _time == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields.')),
      );
      return;
    }

    final dt = DateTime(
      _date!.year, _date!.month, _date!.day, _time!.hour, _time!.minute,
    );

    if (!_isWithinAvailability(dt)) {
      final msg = 'Selected time is outside caregiver working hours.\n'
          'Working hours: ${_availabilityLabel()}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    final total = (_ratePerHour * _estimatedHours);

    final payload = {
      'userId': uid,
      'caregiverId': _caregiverId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),

      'client': {
        'name': _clientName.text.trim(),
        'email': _clientEmail.text.trim(),
        'contact': _clientContact.text.trim(),
      },
      'serviceRecipient': {
        'name': _recName.text.trim(),
        'salutation': _recSalutation.text.trim(),
        'gender': _recGender,
        'contact': _recContact.text.trim(),
        'relationship': _recRelationship.text.trim(),
        'age': _recAge.text.trim(),
        'address': _recAddress.text.trim(),
      },

      'checkUpType': _checkupType.text.trim(),
      'clinicAddress': _clinicAddress.text.trim(),
      'notes': _notes.text.trim(),
      'dateTime': Timestamp.fromDate(dt),
      'estimatedHours': _estimatedHours,

      'ratePerHour': _ratePerHour,
      'totalAmount': total,
    };

    await FirebaseFirestore.instance.collection('bookings').add(payload);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Booking created. Total RM ${total.toStringAsFixed(2)}')),
    );
    Navigator.pop(context);
  }

  // ------------------- UI -------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booking')),
      body: (_loadingUser || _loadingCaregiver)
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _Section('Details of Client:'),
            _in(_clientName, 'Name', required: true),
            const SizedBox(height: 10),
            _in(_clientEmail, 'Email Address',
                keyboard: TextInputType.emailAddress, required: true),
            const SizedBox(height: 10),
            _in(_clientContact, 'Contact',
                keyboard: TextInputType.phone, required: true),

            const SizedBox(height: 16),
            const _Section('Details of Service Recipient:'),
            _in(_recName, 'Care Recipient (name)', required: true),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _in(_recSalutation, 'Salutation')),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _recGender,
                    isExpanded: true,
                    decoration: _dec('Gender', required: true),
                    items: const [
                      DropdownMenuItem(value: 'Male', child: Text('Male')),
                      DropdownMenuItem(value: 'Female', child: Text('Female')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (v) => setState(() => _recGender = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _in(_recContact, 'Contact Number',
                keyboard: TextInputType.phone),
            const SizedBox(height: 10),
            _in(_recRelationship, 'Relationship'),
            const SizedBox(height: 10),
            _in(_recAge, 'Age', keyboard: TextInputType.number),
            const SizedBox(height: 10),
            _in(_recAddress, 'House Address', lines: 3),

            const SizedBox(height: 16),
            _in(_checkupType, 'Select Check-Up Type'),
            const SizedBox(height: 10),
            _in(_clinicAddress, 'Hospital / Clinic Address', required: true),

            const SizedBox(height: 16),
            const _Section('Check-Up Date and Time:'),
            // --- Check-Up Date and Time ---
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final now = DateTime.now();
                      // showDatePicker can return null on some web engines; we also offer a fallback.
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _date ?? now,
                        firstDate: now,
                        lastDate: now.add(const Duration(days: 365)),
                      );

                      picked ??= await showDialog<DateTime>(
                        context: context,
                        builder: (_) {
                          DateTime tmp = _date ?? now;
                          return AlertDialog(
                            title: const Text('Select date'),
                            content: SizedBox(
                              width: 320, height: 320,
                              child: CalendarDatePicker(
                                firstDate: now,
                                lastDate: now.add(const Duration(days: 365)),
                                initialDate: _date ?? now,
                                onDateChanged: (d) => tmp = d,
                              ),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.pop(context, tmp), child: const Text('OK')),
                            ],
                          );
                        },
                      );

                      if (picked != null && mounted) {
                        setState(() => _date = picked);
                      }
                    },
                    child: Text(
                      _date == null
                          ? 'Select Date'
                          : '${_date!.day.toString().padLeft(2, '0')}/${_date!.month.toString().padLeft(2, '0')}/${_date!.year}',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
                      );

                      picked ??= await showDialog<TimeOfDay>(
                        context: context,
                        builder: (_) => TimePickerDialog(
                          initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
                        ),
                      );

                      if (picked != null && mounted) {
                        setState(() => _time = picked);
                      }
                    },
                    child: Text(
                      _time == null
                          ? 'Select Time'
                          : '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // IMPORTANT: values are doubles (2.0, 3.0, …) so the bound value updates correctly
            DropdownButtonFormField<double>(
              value: _estimatedHours,
              isExpanded: true,
              decoration: _dec('Estimated Duration*', required: true),
              items: const [
                DropdownMenuItem(value: 2.0, child: Text('2 hours (minimum)')),
                DropdownMenuItem(value: 3.0, child: Text('3 hours')),
                DropdownMenuItem(value: 4.0, child: Text('4 hours')),
                DropdownMenuItem(value: 5.0, child: Text('5 hours')),
                DropdownMenuItem(value: 6.0, child: Text('6 hours')),
              ],
              onChanged: (v) => setState(() => _estimatedHours = v ?? 2.0),
            ),

            const SizedBox(height: 16),
            _in(_notes, 'Additional Notes',
                hint: 'e.g., "Medical files with my Grandma"', lines: 4),

            const SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: mint, width: 1.2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Payment Summary',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text('Rate per Hour: RM ${_ratePerHour.toStringAsFixed(2)}'),
                    Text('Estimated Duration: ${_estimatedHours.toStringAsFixed(0)} hour(s)'),
                    const Divider(height: 20),
                    Text(
                      'Total Payment: RM ${(_ratePerHour * _estimatedHours).toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: mint,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _saveAndProceed,
                child: const Text('Proceed to Payment'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ------------------- UI helpers -------------------
  static InputDecoration _dec(String label, {bool required = false}) {
    return InputDecoration(
      labelText: required ? '$label *' : label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Widget _in(
      TextEditingController c,
      String label, {
        int lines = 1,
        String? hint,
        TextInputType? keyboard,
        bool required = false,
      }) {
    return TextField(
      controller: c,
      maxLines: lines,
      keyboardType: keyboard,
      decoration: _dec(label, required: required).copyWith(hintText: hint),
    );
  }
}

class _Section extends StatelessWidget {
  final String text;
  const _Section(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
    );
  }
}
