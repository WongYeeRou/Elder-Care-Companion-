import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminManageAllUsers extends StatefulWidget {
  const AdminManageAllUsers({super.key});
  @override
  State<AdminManageAllUsers> createState() => _AdminManageAllUsersState();
}

class _AdminManageAllUsersState extends State<AdminManageAllUsers> {
  String _search = '';
  String _role = ''; // '', 'user', 'caregiver', 'admin'
  final _searchCtrl = TextEditingController();

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance.collection('users');
    return Scaffold(
      appBar: AppBar(title: const Text('All Users')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Search'),
                onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
              ),
            ),
            const SizedBox(width: 12),
            DropdownButton<String>(
              value: _role.isEmpty ? null : _role,
              hint: const Text('Role'),
              items: const [
                DropdownMenuItem(value: 'user', child: Text('User')),
                DropdownMenuItem(value: 'caregiver', child: Text('Caregiver')),
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
              ],
              onChanged: (v) => setState(() => _role = v ?? ''),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: q.snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final rows = snap.data!.docs.where((d) {
                final m = d.data();
                final name = (m['username'] ?? m['name'] ?? '').toString().toLowerCase();
                final email = (m['email'] ?? '').toString().toLowerCase();
                final role = (m['role'] ?? '').toString().toLowerCase();
                final okSearch = _search.isEmpty || name.contains(_search) || email.contains(_search);
                final okRole = _role.isEmpty || role == _role;
                return okSearch && okRole;
              }).toList()
                ..sort((a,b)=>((a.data()['username']??'').toString())
                    .compareTo((b.data()['username']??'').toString()));

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final d = rows[i];
                  final m = d.data();
                  final username = (m['username'] ?? m['name'] ?? '[no name]').toString();
                  final email = (m['email'] ?? '').toString();
                  final role = (m['role'] ?? '').toString();
                  final status = (m['status'] ?? 'active').toString(); // default active

                  return Card(
                    child: ListTile(
                      title: Text(username, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('$email  •  $role  •  Status: $status'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        TextButton(
                          child: Text(status == 'active' ? 'Deactivate' : 'Activate'),
                          onPressed: () async {
                            await d.reference.update({'status': status == 'active' ? 'inactive' : 'active'});
                            // if caregiver too, reflect status for browsing (optional):
                            if (role == 'caregiver') {
                              await FirebaseFirestore.instance.collection('caregivers').doc(d.id).update({
                                'accountStatus': status == 'active' ? 'inactive' : 'active'
                              }).catchError((_){}); // ignore if missing
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          child: const Text('View'),
                          onPressed: () => _showUser(context, d.id, m),
                        ),
                      ]),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }

  void _showUser(BuildContext context, String uid, Map<String,dynamic> m) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('User: $uid', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _kv('Username', m['username']??''),
            _kv('Email', m['email']??''),
            _kv('Role', m['role']??''),
            _kv('Contact', m['contact']??''),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: ()=>Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, Object? v) => ListTile(
    dense: true,
    title: Text(k), subtitle: Text(v?.toString() ?? '-'),
  );
}
