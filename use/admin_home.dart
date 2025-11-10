// lib/admin_home.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'admin_manage_caregiver_request.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _debugAdminClaim(); // Log "isAdmin? true/false" once on entry
  }

  Future<void> _debugAdminClaim() async {
    final user = _auth.currentUser;
    if (user == null) return;
    // Force refresh so latest custom claims are in the token
    await user.getIdToken(true);
    final token = await user.getIdTokenResult();
    debugPrint('isAdmin? ${token.claims?['admin']}'); // expect: true
  }

  @override
  Widget build(BuildContext context) {
    final adminEmail = _auth.currentUser?.email ?? 'Admin';

    // Firestore aggregations
    final usersCount = FirebaseFirestore.instance.collection('users').count();
    final caregiversCount = FirebaseFirestore.instance.collection('caregivers').count();

    // Pending caregiver requests
    final pendingQ = FirebaseFirestore.instance
        .collection('caregivers')
        .where('status', isEqualTo: 'pending');

    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Home — $adminEmail'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _auth.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text('Caregiver SignUp Request', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),

            // Pending requests list
            StreamBuilder<QuerySnapshot>(
              stream: pendingQ.snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }
                if (snap.hasError) {
                  return Text('Error: ${snap.error}');
                }
                final docs = snap.data?.docs ?? const [];
                if (docs.isEmpty) {
                  return const Text('No pending requests.');
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final d = docs[i];
                    final m = d.data() as Map<String, dynamic>;
                    final name = (m['fullName'] ?? m['email'] ?? d.id) as String;

                    return Card(
                      child: ListTile(
                        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('uid: ${d.id}', maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: TextButton(
                          child: const Text('Manage'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => AdminManageCaregiver(uid: d.id)),
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 16),

            // Stats row
            Row(
              children: [
                Expanded(
                  child: _CountCard(
                    label: 'Total Registered Users',
                    count: usersCount,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CountCard(
                    label: 'Total Registered Caregivers',
                    count: caregiversCount,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // (Optional) quick refresh claims button for testing
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Admin Claim (debug)'),
              onPressed: _debugAdminClaim,
            ),
          ],
        ),
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  final String label;
  final AggregateQuery count;

  const _CountCard({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            FutureBuilder<AggregateQuerySnapshot>(
              future: count.get(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 28,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                }
                final n = snap.hasData ? snap.data!.count : 0;
                return Text(
                  '$n',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
