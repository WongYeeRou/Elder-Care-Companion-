// lib/user_home.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_booking_page.dart';          // your caregiver browser / make booking page
import 'user_my_bookings.dart';           // NEW (below)
import 'manage_loved_one.dart';

class UserHomeShell extends StatefulWidget {
  static const route = '/user/home';
  const UserHomeShell({super.key});

  @override
  State<UserHomeShell> createState() => _UserHomeShellState();
}

class _UserHomeShellState extends State<UserHomeShell> {
  static const mint = Color(0xFF33C7B6);
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _checkPendingApprovalMessage();
  }

  /// One-time dialog when a booking (created in last 24h) exists.
  Future<void> _checkPendingApprovalMessage() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final qs = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: uid)
          .where('status', isEqualTo: 'upcoming')
          .orderBy('createdAt', descending: true) // if index error, remove and keep
          .limit(1)
          .get();

      if (qs.docs.isEmpty) return;

      final booking = qs.docs.first.data();
      final ts = booking['createdAt'];
      if (ts is! Timestamp) return;

      final approvedAt = ts.toDate();
      final diffHours = DateTime.now().difference(approvedAt).inHours;
      if (diffHours < 24 && mounted) {
        _showApprovedDialog(context);
      }
    } catch (_) {
      // ignore – don't block home
    }
  }

  void _showApprovedDialog(BuildContext context) {
    final username =
        FirebaseAuth.instance.currentUser?.email?.split('@').first ?? 'User';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 72),
            const SizedBox(height: 16),
            Text(
              'Cash-in by $username approved.\nYour booking has been confirmed!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: mint,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                minimumSize: const Size.fromHeight(44),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const _UserHome(),
      const BookingPage(),                 // browse caregivers + make booking (you already have)
      const UserMyBookingsPage(),          // NEW: tabs + lists
      const _FeedbackEntry(),              // simple entry to your feedback page
      const _Profile(),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined), label: 'Booking'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), label: 'My Bookings'),
          NavigationDestination(icon: Icon(Icons.feedback_outlined), label: 'Feedback'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

/* ---------------- Home content ---------------- */

class _UserHome extends StatelessWidget {
  const _UserHome();

  @override
  Widget build(BuildContext context) {
    final name = FirebaseAuth.instance.currentUser?.email ?? 'User';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Welcome, ${name.split('@').first}',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),

        // Quick panel – go to My Bookings
        Card(
          child: ListTile(
            title: const Text('My Bookings'),
            subtitle: const Text('Upcoming • Ongoing • Completed'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserMyBookingsPage()),
            ),
          ),
        ),

        const SizedBox(height: 16),
        Card(
          child: ListTile(
            title: const Text('Make a new booking'),
            subtitle: const Text('Browse verified caregivers'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BookingPage()),
            ),
          ),
        ),
      ],
    );
  }
}

class _FeedbackEntry extends StatelessWidget {
  const _FeedbackEntry();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: OutlinedButton.icon(
          icon: const Icon(Icons.feedback_outlined),
          label: const Text('Open Feedbacks'),
          onPressed: () => Navigator.pushNamed(context, '/feedbacks'),
        ),
      ),
    );
  }
}

class _Profile extends StatelessWidget {
  const _Profile();
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text('My Profile',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      ElevatedButton(
        onPressed: () =>
            Navigator.pushNamed(context, ManageLovedOnePage.route),
        child: const Text('Manage Loved One'),
      ),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: () async {
          await FirebaseAuth.instance.signOut();
          if (context.mounted) {
            Navigator.pushReplacementNamed(context, '/login');
          }
        },
        child: const Text('Logout'),
      ),
    ],
  );
}
