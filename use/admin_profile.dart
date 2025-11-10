import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminProfilePage extends StatefulWidget {
  const AdminProfilePage({super.key});
  @override
  State<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage> {
  final _pwd1 = TextEditingController();
  final _pwd2 = TextEditingController();
  bool _busy = false;

  @override
  void dispose() { _pwd1.dispose(); _pwd2.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(title: const Text('Email'), subtitle: Text(user?.email ?? '-')),
          const Divider(),
          const Text('Change Password', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(controller: _pwd1, obscureText: true, decoration: const InputDecoration(labelText: 'New Password')),
          const SizedBox(height: 12),
          TextField(controller: _pwd2, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm Password')),
          const SizedBox(height: 12),
          SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: _busy ? null : _changePwd,
              child: const Text('Update Password'),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
    );
  }

  Future<void> _changePwd() async {
    if (_pwd1.text.length < 6 || _pwd1.text != _pwd2.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password mismatch (min 6 chars).')));
      return;
    }
    setState(()=>_busy = true);
    try {
      await FirebaseAuth.instance.currentUser?.updatePassword(_pwd1.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated.')));
        _pwd1.clear(); _pwd2.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally { if (mounted) setState(()=>_busy = false); }
  }
}
