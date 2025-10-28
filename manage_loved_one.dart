import 'package:flutter/material.dart';

class CareRecipient {
  final String fullName;
  final String salutation;
  final String gender;
  final String language;
  final String relationship;
  final int age;
  final String address;

  CareRecipient({
    required this.fullName,
    required this.salutation,
    required this.gender,
    required this.language,
    required this.relationship,
    required this.age,
    required this.address,
  });
}

class ManageLovedOnePage extends StatefulWidget {
  const ManageLovedOnePage({super.key});

  @override
  State<ManageLovedOnePage> createState() => _ManageLovedOnePageState();
}

class _ManageLovedOnePageState extends State<ManageLovedOnePage> {
  final List<CareRecipient> _recipients = [
    CareRecipient(
      fullName: "Lim Xiao Xiao",
      salutation: "Mr",
      gender: "Male",
      language: "Chinese",
      relationship: "Father",
      age: 74,
      address: "123, Jalan Penang, George Town",
    ),
    CareRecipient(
      fullName: "Lim Laila",
      salutation: "Mrs",
      gender: "Female",
      language: "Malay",
      relationship: "Mother",
      age: 70,
      address: "123, Jalan Penang, George Town",
    ),
  ];

  void _addRecipient() {
    // For prototype: always add dummy
    setState(() {
      _recipients.add(
        CareRecipient(
          fullName: "New Recipient",
          salutation: "Mr",
          gender: "Male",
          language: "English",
          relationship: "Friend",
          age: 65,
          address: "Random Address",
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Loved Ones")),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _recipients.length,
        itemBuilder: (context, i) {
          final r = _recipients[i];
          return Card(
            child: ListTile(
              title: Text("${r.salutation} ${r.fullName}"),
              subtitle: Text("${r.relationship}, ${r.age} yrs, ${r.language}"),
              onTap: () => Navigator.pop(context, r), // return selected
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addRecipient,
        child: const Icon(Icons.add),
      ),
    );
  }
}
