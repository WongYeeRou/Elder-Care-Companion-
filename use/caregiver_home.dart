// lib/caregiver_home.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:async/async.dart';

import 'caregiver_bookings.dart';

class CaregiverHome extends StatefulWidget {
  static const route = '/caregiver/home';
  const CaregiverHome({super.key});

  @override
  State<CaregiverHome> createState() => _CaregiverHomeState();
}

class _CaregiverHomeState extends State<CaregiverHome> {
  static const Color mint = Color(0xFF33C7B6);
  bool _hideMoney = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  Stream<String> _username() {
    final uid = _user?.uid;
    if (uid == null) return Stream<String>.value('Caregiver');
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((d) => (d.data()?['username'] ?? 'Caregiver').toString());
  }

  Query<Map<String, dynamic>> _q(String status) {
    return FirebaseFirestore.instance
        .collection('bookings')
        .where('caregiverId', isEqualTo: _user?.uid)
        .where('status', isEqualTo: status);
  }

  Stream<int> _count(String status) => _q(status).snapshots().map((s) => s.size);

  Stream<num> _earnings() => FirebaseFirestore.instance
      .collection('bookings')
      .where('caregiverId', isEqualTo: _user?.uid)
      .where('status', isEqualTo: 'completed')
      .snapshots()
      .map((snap) {
    num sum = 0;
    for (final d in snap.docs) {
      final v = d.data()['totalAmount'];
      if (v is num) sum += v;
    }
    return sum;
  });

  Stream<QuerySnapshot<Map<String, dynamic>>> _newRequests() =>
      FirebaseFirestore.instance
          .collection('bookings')
          .where('caregiverId', isEqualTo: _user?.uid)
          .where('status', isEqualTo: 'pending')
          .orderBy('dateTime', descending: true)
          .limit(5)
          .snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<String>(
          stream: _username(),
          builder: (context, snap) {
            final name = (snap.data ?? 'Caregiver').trim();
            return Text('Welcome, $name');
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: _KpiCard(
                    title: 'Upcoming Jobs',
                    stream: StreamZip<int>([
                      _count('pending'),
                      _count('ongoing'),
                    ]).map((two) => two[0] + two[1]),
                    mint: mint,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _KpiCard(
                    title: 'Total Jobs Completed',
                    stream: _count('completed'),
                    mint: mint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: mint, width: 1.2),
              ),
              child: Padding(
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader('Total Earnings'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: StreamBuilder<num>(
                            stream: _earnings(),
                            builder: (context, snap) {
                              final amount = (snap.data ?? 0).toDouble();
                              final text = _hideMoney
                                  ? 'RM ••••••'
                                  : 'RM ${amount.toStringAsFixed(2)}';
                              return Text(
                                text,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              );
                            },
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => _hideMoney = !_hideMoney),
                          icon: Icon(
                            _hideMoney
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            const _SectionHeader('New Booking Request'),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _newRequests(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }
                final docs = snap.data?.docs ?? const [];
                if (docs.isEmpty) {
                  return const _EmptyCard(
                    text: 'No new requests. You’ll see the latest here.',
                  );
                }
                return Column(
                  children: docs.map((d) {
                    final data = d.data();
                    final careName = (data['careRecipientName'] ?? '') as String;
                    final clientName = (data['clientName'] ?? '') as String;
                    final ts = data['dateTime'];
                    DateTime? dt;
                    if (ts is Timestamp) dt = ts.toDate();

                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.assignment_outlined),
                        title: Text(
                          careName.isEmpty ? 'Care recipient' : careName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text([
                          if (clientName.isNotEmpty) clientName,
                          if (dt != null) '${_dd(dt)} ${_hhmm(dt)}',
                        ].join(' · ')),
                        trailing: TextButton(
                          child: const Text('View'),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const CaregiverBookingsPage(),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              break;
            case 1:
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CaregiverBookingsPage()),
              );
              break;
            case 2:
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Wallet coming soon')),
              );
              break;
            case 3:
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Feedback coming soon')),
              );
              break;
            case 4:
              Navigator.pushNamed(context, '/caregiver');
              break;
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.inbox_outlined), label: 'Bookings'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Wallet'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Feedback'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }

  static String _dd(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  static String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/* ---------- helpers ---------- */

class _KpiCard extends StatelessWidget {
  final String title;
  final Stream<int> stream;
  final Color mint;
  const _KpiCard({required this.title, required this.stream, required this.mint});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: mint, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                // If your SDK doesn’t have withValues, switch back to withOpacity(0.15)
                color: mint.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Upcoming Jobs',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 10),
            StreamBuilder<int>(
              stream: stream,
              builder: (context, snap) {
                final v = snap.data ?? 0;
                return Text(
                  '$v',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700));
}

class _EmptyCard extends StatelessWidget {
  final String text;
  const _EmptyCard({required this.text});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.info_outline),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    ),
  );
}
