import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'caregiver_bookings.dart';

// TODO: replace these with your real pages
class _CaregiverHome extends StatelessWidget {
  const _CaregiverHome();
  @override
  Widget build(BuildContext context) {
    final name = FirebaseAuth.instance.currentUser?.email ?? 'Caregiver';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Welcome, ${name.split('@').first}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            title: const Text('Total Earnings'),
            subtitle: const Text('RM 0.00'),
            trailing: const Icon(Icons.visibility_outlined),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Messages coming soon',
            style: TextStyle(color: Colors.black54)),
      ],
    );
  }
}

class _WalletPage extends StatelessWidget {
  const _WalletPage();
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Withdrawal (Wallet) — coming soon'));
}

class _FeedbacksPage extends StatelessWidget {
  const _FeedbacksPage();
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Feedback — coming soon'));
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage();
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text('My Profile',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
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

/// A nested-Navigator shell so the bottom bar stays visible while pushing pages.
class CaregiverShell extends StatefulWidget {
  static const route = '/caregiver/shell';
  const CaregiverShell({super.key});

  @override
  State<CaregiverShell> createState() => _CaregiverShellState();
}

class _CaregiverShellState extends State<CaregiverShell> {
  int _index = 0;

  final _navigatorKeys = List.generate(5, (_) => GlobalKey<NavigatorState>());

  Widget _buildTabNavigator(int tab) {
    late final Widget root;
    switch (tab) {
      case 0:
        root = const _CaregiverHome();
        break;
      case 1:
        root = const CaregiverBookingsPage(); // << your bookings page
        break;
      case 2:
        root = const _WalletPage();
        break;
      case 3:
        root = const _FeedbacksPage();
        break;
      default:
        root = const _ProfilePage();
    }

    return Navigator(
      key: _navigatorKeys[tab],
      onGenerateRoute: (settings) => MaterialPageRoute(
        builder: (_) => root,
        settings: settings,
      ),
    );
  }

  Future<bool> _onWillPop() async {
    final nav = _navigatorKeys[_index].currentState!;
    if (nav.canPop()) {
      nav.pop();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: List.generate(5, _buildTabNavigator),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.assignment_outlined), label: 'Bookings'),
            NavigationDestination(icon: Icon(Icons.savings_outlined), label: 'Withdraw'),
            NavigationDestination(icon: Icon(Icons.feedback_outlined), label: 'Feedback'),
            NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
