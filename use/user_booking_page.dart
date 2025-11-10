// lib/user_booking_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'user_view_caregiver_detail.dart';

class BookingPage extends StatefulWidget {
  static const route = '/booking';
  const BookingPage({super.key});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  static const Color mint = Color(0xFF33C7B6);

  String? _region;
  String? _language;
  String _search = '';

  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Build a stream that never requires a composite index:
  // besides status=='approved', apply at most ONE extra equality on the server.
  Stream<QuerySnapshot<Map<String, dynamic>>> _caregiversStream() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('caregivers')
        .where('status', isEqualTo: 'approved');

    final hasRegion = (_region ?? '').isNotEmpty;
    final hasLang = (_language ?? '').isNotEmpty;

    if (hasRegion && !hasLang) {
      q = q.where('region', isEqualTo: _region);
    } else if (!hasRegion && hasLang) {
      q = q.where('language', isEqualTo: _language);
    }
    // If both are selected, we filter the second one client-side.

    return q.limit(200).snapshots(); // no orderBy -> no index needed
  }

  bool _matchesClientSide(Map<String, dynamic> data) {
    if ((_region ?? '').isNotEmpty && data['region'] != _region) return false;
    if ((_language ?? '').isNotEmpty && data['language'] != _language) return false;

    if (_search.isNotEmpty) {
      final hay = [
        (data['fullName'] ?? '').toString(),
        (data['contact'] ?? '').toString(),
        (data['region'] ?? '').toString(),
        (data['language'] ?? '').toString(),
      ].join(' ').toLowerCase();
      if (!hay.contains(_search.toLowerCase())) return false;
    }
    return true;
  }

  void _clear() {
    setState(() {
      _region = null;
      _language = null;
      _search = '';
      _searchCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booking')),
      body: SafeArea(
        child: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, authSnap) {
            if (authSnap.data == null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Please log in to view caregivers.'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/login'),
                      child: const Text('Go to Login'),
                    ),
                  ],
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _region,
                  decoration: const InputDecoration(
                    labelText: 'Select Region in Penang',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'George Town', child: Text('George Town')),
                    DropdownMenuItem(value: 'Bayan Lepas', child: Text('Bayan Lepas')),
                    DropdownMenuItem(value: 'Butterworth', child: Text('Butterworth')),
                  ],
                  onChanged: (v) => setState(() => _region = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _language,
                  decoration: const InputDecoration(
                    labelText: 'Select Preferred Language',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'English', child: Text('English')),
                    DropdownMenuItem(value: 'Malay', child: Text('Malay')),
                    DropdownMenuItem(value: 'Chinese', child: Text('Chinese')),
                    DropdownMenuItem(value: 'Tamil', child: Text('Tamil')),
                  ],
                  onChanged: (v) => setState(() => _language = v),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => setState(() {}),
                        child: const Text('Apply'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _clear,
                        child: const Text('Clear'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Search Caregiver',
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
                const SizedBox(height: 12),

                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _caregiversStream(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snap.hasError) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Text(
                          'Error: ${snap.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    }

                    final docs = (snap.data?.docs ?? const [])
                        .where((d) => _matchesClientSide(d.data()))
                        .toList()
                      ..sort((a, b) =>
                          (a.data()['fullName'] ?? '').toString().toLowerCase().compareTo(
                            (b.data()['fullName'] ?? '').toString().toLowerCase(),
                          ));

                    if (docs.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 28),
                        child: Text(
                          'No verified caregivers found.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black.withOpacity(.65)),
                        ),
                      );
                    }

                    return Column(
                      children: docs.map((d) {
                        final data = d.data();
                        final name = (data['fullName'] ?? '') as String;
                        final region = (data['region'] ?? '') as String? ?? '';
                        final lang = (data['language'] ?? '') as String? ?? '';
                        final years = (data['yearsOfExperience'] ?? 0).toString();
                        final rate = (data['ratePerHour'] ?? 0).toString();
                        final contact = (data['contact'] ?? '') as String? ?? '';
                        final profile =
                            (data['attachments']?['profilePic'] ?? '') as String? ?? '';

                        return Card(
                          child: ListTile(
                            contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundImage:
                              profile.isNotEmpty ? NetworkImage(profile) : null,
                              child: profile.isEmpty ? const Icon(Icons.person) : null,
                            ),
                            title: Text(
                              name.isEmpty ? 'Caregiver' : name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              [
                                if (region.isNotEmpty) region,
                                if (lang.isNotEmpty) ' • $lang',
                                if (years.isNotEmpty) ' • $years yrs',
                                if (rate.isNotEmpty) ' • RM $rate/hr',
                                if (contact.isNotEmpty) ' • ☎ $contact',
                              ].join(''),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            // 👇 Constrain trailing so it cannot take full width.
                            trailing: ConstrainedBox(
                              constraints: const BoxConstraints.tightFor(width: 90, height: 36),
                              child: TextButton(
                                onPressed: () {
                                  Navigator.pushNamed(
                                    context,
                                    CaregiverDetailPage.route,
                                    arguments: CaregiverDetailArgs(caregiverId: d.id),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  padding:
                                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  minimumSize: const Size(90, 36),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    side: const BorderSide(color: mint),
                                  ),
                                ),
                                child: const Text('View'),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

                const SizedBox(height: 32),
              ],
            );
          },
        ),
      ),
    );
  }
}
