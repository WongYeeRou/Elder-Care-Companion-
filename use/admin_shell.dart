import 'package:flutter/material.dart';
import 'admin_home.dart';
import 'admin_manage_all_users.dart';
import 'admin_user_finance.dart';
import 'admin_caregiver_finance.dart';
import 'admin_feedbacks.dart';
import 'admin_profile.dart';

class AdminShell extends StatefulWidget {
  static const route = '/admin';
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;
  static const mint = Color(0xFF33C7B6);

  final _pages = const [
    AdminHome(),               // caregiver sign-up approvals (you already had)
    AdminManageAllUsers(),     // users + caregivers, status Active/Inactive
    AdminUserFinancePage(),    // cash-in / additional / retrieve
    AdminCaregiverFinance(),   // withdrawal
    AdminFeedbacksPage(),      // all feedbacks
    AdminProfilePage(),        // change password
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        indicatorColor: mint.withOpacity(.18),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.group_outlined), selectedIcon: Icon(Icons.group), label: 'Users'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'User \$'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Caregiver \$'),
          NavigationDestination(icon: Icon(Icons.feedback_outlined), selectedIcon: Icon(Icons.feedback), label: 'Feedbacks'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
