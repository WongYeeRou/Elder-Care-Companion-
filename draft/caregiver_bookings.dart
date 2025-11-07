// lib/caregiver_bookings.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'caregiver_home.dart';

class CaregiverBookingsPage extends StatefulWidget {
  static const route = '/caregiver/bookings';
  const CaregiverBookingsPage({super.key});

  @override
  State<CaregiverBookingsPage> createState() => _CaregiverBookingsPageState();
}

class _CaregiverBookingsPageState extends State<CaregiverBookingsPage>
    with SingleTickerProviderStateMixin {
  static const Color mint = Color(0xFF33C7B6);

  late final TabController _tabs;
  final _searchCtrl = TextEditingController(); // ✅ search controller
  int _bottomIndex = 1;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ---------------------------- data ---------------------------------

  Query<Map<String, dynamic>> _baseQ(String status) {
    return FirebaseFirestore.instance
        .collection('bookings')
        .where('caregiverId', isEqualTo: _uid)
        .where('status', isEqualTo: status)
        .orderBy('dateTime', descending: true);
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _stream(String status) {
    return _baseQ(status).snapshots().map((s) => s.docs);
  }

  // -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.pop(context)),
        title: const Text('My Bookings'),
        // Use a fixed-height PreferredSize to avoid AppBar overflow warnings.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(98),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: mint, width: 1.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TabBar(
                  controller: _tabs,
                  labelColor: Colors.black,
                  unselectedLabelColor: Colors.black54,
                  indicator: BoxDecoration(
                    color: mint.withOpacity(.22),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  tabs: const [
                    Tab(text: 'Pending'),
                    Tab(text: 'Ongoing'),
                    Tab(text: 'Completed'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      body: SafeArea(
        child: TabBarView(
          controller: _tabs,
          children: [
            _BookingsList(
              stream: _stream('pending'),
              emptyText: 'No pending bookings.',
              queryText: () => _searchCtrl.text,
              showUpdate: false,
            ),
            _BookingsList(
              stream: _stream('ongoing'),
              emptyText: 'No ongoing bookings.',
              queryText: () => _searchCtrl.text,
              showUpdate: true,
            ),
            _BookingsList(
              stream: _stream('completed'),
              emptyText: 'No completed bookings.',
              queryText: () => _searchCtrl.text,
              showUpdate: false,
            ),
          ],
        ),
      ),

      // ----------------------- bottom nav ------------------------------
      bottomNavigationBar: NavigationBar(
        selectedIndex: _bottomIndex,
        onDestinationSelected: (i) {
          setState(() => _bottomIndex = i);
          switch (i) {
            case 0:
              Navigator.pushNamedAndRemoveUntil(
                  context, CaregiverHome.route, (_) => false);
              break;
            case 1:
            // already here
              break;
            case 2:
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Wallet coming soon')),
              );
              break;
            case 3:
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Messages coming soon')),
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
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Messages'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

/* --------------------------- widgets ---------------------------- */

class _BookingsList extends StatelessWidget {
  final Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> stream;
  final String emptyText;
  final String Function() queryText;
  final bool showUpdate;

  const _BookingsList({
    required this.stream,
    required this.emptyText,
    required this.queryText,
    required this.showUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }

        final docs = snap.data ?? const [];
        final q = queryText().trim().toLowerCase();

        final filtered = (q.isEmpty)
            ? docs
            : docs.where((d) {
          final m = d.data();
          final careName = (m['careRecipientName'] ?? '').toString().toLowerCase();
          final clientName = (m['clientName'] ?? '').toString().toLowerCase();
          final id = (d.id).toLowerCase();
          return careName.contains(q) || clientName.contains(q) || id.contains(q);
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Text(
              emptyText,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final data = filtered[i].data();
            final id = filtered[i].id;
            final care = (data['careRecipientName'] ?? '') as String? ?? '';
            final client = (data['clientName'] ?? '') as String? ?? '';
            final ts = data['dateTime'];
            DateTime? dt;
            if (ts is Timestamp) dt = ts.toDate();

            return Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('Booking ID: $id',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                        Text(
                          (data['status'] ?? '').toString().isEmpty
                              ? ''
                              : (data['status'] as String).substring(0, 1).toUpperCase() +
                              (data['status'] as String).substring(1),
                          style: TextStyle(
                            color: Colors.black.withOpacity(.6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _chip('Care Recipient Name', care),
                        const SizedBox(width: 8),
                        _chip('Client Name', client),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            dt == null
                                ? 'Date —'
                                : '${_dd(dt)}   ${_hhmm(dt)}',
                            style: TextStyle(color: Colors.black.withOpacity(.7)),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // TODO: navigate to details page
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('View details coming soon')),
                            );
                          },
                          child: const Text('View'),
                        ),
                        if (showUpdate)
                          TextButton(
                            onPressed: () {
                              // TODO: update status page
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Update flow coming soon')),
                              );
                            },
                            child: const Text('Update'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Widget _chip(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.black.withOpacity(.55),
              )),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.black.withOpacity(.25)),
            ),
            child: Text(
              value.isEmpty ? '—' : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  static String _dd(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  static String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
