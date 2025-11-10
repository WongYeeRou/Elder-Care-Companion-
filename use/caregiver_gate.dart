// lib/caregiver_gate.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'caregiver_home.dart';
import 'caregiver_signup.dart';

class CaregiverGate extends StatefulWidget {
  const CaregiverGate({super.key});

  @override
  State<CaregiverGate> createState() => _CaregiverGateState();
}

class _CaregiverGateState extends State<CaregiverGate> {
  bool _acted = false; // prevents repeated navigations/snackbars on stream updates

  void _postFrame(VoidCallback fn) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      fn();
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const _CenteredText('Please log in first.');
    }

    final docRef = FirebaseFirestore.instance.doc('caregivers/$uid');

    return StreamBuilder<DocumentSnapshot>(
      stream: docRef.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _Loading();
        }

        // No caregiver doc — show CTA to sign up (no auto nav here)
        if (!snap.hasData || !snap.data!.exists) {
          return _CenteredActions(
            title: 'Complete your caregiver profile',
            body: 'We couldn’t find your caregiver record.',
            primary: ElevatedButton(
              onPressed: () => Navigator.pushReplacementNamed(
                context,
                CaregiverSignUpPage.route,
              ),
              child: const Text('Go to Caregiver Sign Up'),
            ),
          );
        }

        final data = snap.data!.data() as Map<String, dynamic>;
        final status = (data['status'] ?? 'pending') as String;

        if (!_acted && status == 'approved') {
          _acted = true;
          _postFrame(() {
            Navigator.pushNamedAndRemoveUntil(
              context,
              CaregiverHome.route,
                  (_) => false,
            );
          });
        } else if (!_acted && status == 'pending') {
          _acted = true;
          _postFrame(() {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Your application is still pending approval.')),
            );
          });
        } else if (status == 'rejected') {
          final reason = (data['rejectionReason'] ?? 'Not specified') as String;
          return _CenteredActions(
            title: 'Application Rejected',
            body: 'Reason: $reason',
            primary: ElevatedButton(
              onPressed: () => Navigator.pushReplacementNamed(
                context,
                CaregiverSignUpPage.route,
              ),
              child: const Text('Edit & Resubmit'),
            ),
          );
        }

        // Fallback UI while we just showed a snackbar or are about to route
        return const _CenteredText('Your account is waiting to be confirmed by admin.');
      },
    );
  }
}

class _CenteredText extends StatelessWidget {
  final String text;
  const _CenteredText(this.text);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Caregiver')),
    body: Center(child: Text(text, textAlign: TextAlign.center)),
  );
}

class _CenteredActions extends StatelessWidget {
  final String title, body;
  final Widget primary;
  const _CenteredActions({required this.title, required this.body, required this.primary});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Caregiver')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(body, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        primary,
      ]),
    ),
  );
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );
}
