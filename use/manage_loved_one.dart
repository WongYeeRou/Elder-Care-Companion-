// lib/manage_loved_one.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ManageLovedOneArgs {
  final bool pickMode; // if true, return selected profile back to caller
  const ManageLovedOneArgs({this.pickMode = false});
}

class ManageLovedOnePage extends StatefulWidget {
  static const route = '/manage-loved-one';
  const ManageLovedOnePage({super.key});

  @override
  State<ManageLovedOnePage> createState() => _ManageLovedOnePageState();
}

class _ManageLovedOnePageState extends State<ManageLovedOnePage> {
  static const mint = Color(0xFF33C7B6);

  User? get _user => FirebaseAuth.instance.currentUser;

  CollectionReference<Map<String, dynamic>> _col() {
    final uid = _user!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('careRecipients');
  }

  Future<void> _openCreateForm() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateLovedOneSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as ManageLovedOneArgs? ??
            const ManageLovedOneArgs();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Care Recipient"),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _col().orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? const [];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              if (docs.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'No care recipients yet.',
                    style: TextStyle(color: Colors.black.withOpacity(.65)),
                  ),
                ),
              ...docs.map((d) {
                final data = d.data();
                final name = (data['fullName'] ?? '') as String;
                final age = (data['age'] ?? '').toString();
                final lang = (data['preferredLanguage'] ?? '') as String;

                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.elderly),
                    title: Text(name.isEmpty ? 'Care recipient' : name),
                    subtitle: Text([
                      if (age.isNotEmpty) 'Age: $age',
                      if (lang.isNotEmpty) ' • $lang',
                    ].join('')),
                    trailing: args.pickMode
                        ? ElevatedButton(
                      onPressed: () => Navigator.pop(context, {
                        'id': d.id,
                        ...data,
                      }),
                      child: const Text('Apply'),
                    )
                        : null,
                  ),
                );
              }),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _openCreateForm,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Add Care Recipient'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/* -------------------- create sheet -------------------- */

class _CreateLovedOneSheet extends StatefulWidget {
  const _CreateLovedOneSheet();

  @override
  State<_CreateLovedOneSheet> createState() => _CreateLovedOneSheetState();
}

class _CreateLovedOneSheetState extends State<_CreateLovedOneSheet> {
  final _f = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _salutation = TextEditingController();
  final _gender = ValueNotifier<String?>(null);
  final _language = ValueNotifier<String?>(null);
  final _relationship = TextEditingController();
  final _age = TextEditingController();
  final _address = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _salutation.dispose();
    _relationship.dispose();
    _age.dispose();
    _address.dispose();
    _gender.dispose();
    _language.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_f.currentState?.validate() ?? false)) return;

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('careRecipients');

    await col.add({
      'fullName': _name.text.trim(),
      'salutation': _salutation.text.trim(),
      'gender': _gender.value,
      'preferredLanguage': _language.value,
      'relationship': _relationship.text.trim(),
      'age': int.tryParse(_age.text.trim()),
      'address': _address.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        // makes bottom sheet scrollable and sized to content
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _f,
            child: Column(
              mainAxisSize: MainAxisSize.min, // <- avoid layout assertion
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text("Let's Create Your Care Profile",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Full Name (As per NRIC)'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _salutation,
                        decoration: const InputDecoration(labelText: 'Salutation'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ValueListenableBuilder<String?>(
                        valueListenable: _gender,
                        builder: (_, g, __) => DropdownButtonFormField<String>(
                          value: g,
                          decoration: const InputDecoration(labelText: 'Gender'),
                          items: const [
                            DropdownMenuItem(value: 'Male', child: Text('Male')),
                            DropdownMenuItem(value: 'Female', child: Text('Female')),
                            DropdownMenuItem(value: 'Other', child: Text('Other')),
                          ],
                          onChanged: (v) => _gender.value = v,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ValueListenableBuilder<String?>(
                  valueListenable: _language,
                  builder: (_, l, __) => DropdownButtonFormField<String>(
                    value: l,
                    decoration: const InputDecoration(labelText: 'Select Preferred Language'),
                    items: const [
                      DropdownMenuItem(value: 'English', child: Text('English')),
                      DropdownMenuItem(value: 'Malay', child: Text('Malay')),
                      DropdownMenuItem(value: 'Chinese', child: Text('Chinese')),
                      DropdownMenuItem(value: 'Tamil', child: Text('Tamil')),
                    ],
                    onChanged: (v) => _language.value = v,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _relationship,
                  decoration: const InputDecoration(labelText: 'Relationship'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _age,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Age'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _address,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'House Address'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _save,
                  child: const Text('Create Profile'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
