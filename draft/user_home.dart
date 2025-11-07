import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'user_booking_page.dart';
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
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const _UserHome(),
      const BookingPage(),
      const _Stub(title: 'Inbox (Coming soon)'),
      const _Stub(title: 'Messages (Coming soon)'),
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
          NavigationDestination(icon: Icon(Icons.inbox_outlined), label: 'Inbox'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Messages'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

class _UserHome extends StatelessWidget {
  const _UserHome();

  static const mint = Color(0xFF33C7B6);

  @override
  Widget build(BuildContext context) {
    final name = FirebaseAuth.instance.currentUser?.email ?? 'User';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Welcome, ${name.split('@').first}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        // My favourite caregivers (placeholder)
        _SectionHeader('My Favourite Caregiver'),
        Row(
          children: const [
            Expanded(child: _FavCard()),
            SizedBox(width: 12),
            Expanded(child: _FavCard()),
          ],
        ),
        const SizedBox(height: 16),
        _SectionHeader('My Care Recipient'),
        Row(
          children: const [
            Expanded(child: _LovedCard()),
            SizedBox(width: 12),
            Expanded(child: _LovedCard()),
          ],
        ),
        const SizedBox(height: 16),
        _SectionHeader('My Booking'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Care Recipient Name',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text('Date · Time'),
                ],
              )),
              TextButton(
                child: const Text('View'),
                onPressed: () {}, // hook to your bookings list for USER
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
  );
}

class _FavCard extends StatelessWidget {
  const _FavCard();
  @override
  Widget build(BuildContext context) => Card(
    child: SizedBox(
      height: 100,
      child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: const [
            Icon(Icons.face_retouching_natural, size: 36),
            SizedBox(height: 4),
            Text('Name'),
            Text('Contact Number'),
          ])),
    ),
  );
}

class _LovedCard extends StatelessWidget {
  const _LovedCard();
  @override
  Widget build(BuildContext context) => Card(
    child: SizedBox(
      height: 100,
      child: Center(
          child:
          Column(mainAxisSize: MainAxisSize.min, children: const [
            Icon(Icons.elderly, size: 36),
            SizedBox(height: 4),
            Text('Name'),
            Text('Age'),
          ])),
    ),
  );
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
        onPressed: () => Navigator.pushNamed(context, ManageLovedOnePage.route),
        child: const Text('Manage Loved One'),
      ),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: () async {
          await FirebaseAuth.instance.signOut();
          if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
        },
        child: const Text('Logout'),
      ),
    ],
  );
}

class _Stub extends StatelessWidget {
  final String title;
  const _Stub({required this.title});
  @override
  Widget build(BuildContext context) =>
      Center(child: Text(title, style: const TextStyle(fontSize: 16)));
}
