import 'package:flutter/material.dart';
import 'manage_loved_one.dart';

class BookingPage extends StatefulWidget {
  const BookingPage({super.key});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  CareRecipient? _selectedRecipient;
  String? _region;
  String? _language;
  DateTime? _date;
  TimeOfDay? _time;

  void _pickDate() async {
    final now = DateTime.now();
    final res = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 1),
      initialDate: _date ?? now,
    );
    if (res != null) setState(() => _date = res);
  }

  void _pickTime() async {
    final res = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (res != null) setState(() => _time = res);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Booking")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Recipient field
          TextField(
            controller: TextEditingController(
              text: _selectedRecipient == null
                  ? ''
                  : "${_selectedRecipient!.salutation} ${_selectedRecipient!.fullName}",
            ),
            readOnly: true,
            decoration: InputDecoration(
              labelText: "Care Recipient",
              suffixIcon: IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () async {
                  final picked = await Navigator.push<CareRecipient>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ManageLovedOnePage(),
                    ),
                  );
                  if (picked != null) {
                    setState(() => _selectedRecipient = picked);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 14),

          DropdownButtonFormField<String>(
            value: _region,
            decoration: const InputDecoration(labelText: "Select Region in Penang"),
            items: const [
              DropdownMenuItem(value: "George Town", child: Text("George Town")),
              DropdownMenuItem(value: "Bayan Lepas", child: Text("Bayan Lepas")),
              DropdownMenuItem(value: "Butterworth", child: Text("Butterworth")),
            ],
            onChanged: (v) => setState(() => _region = v),
          ),
          const SizedBox(height: 14),

          DropdownButtonFormField<String>(
            value: _language,
            decoration: const InputDecoration(labelText: "Select Preferred Language"),
            items: const [
              DropdownMenuItem(value: "English", child: Text("English")),
              DropdownMenuItem(value: "Malay", child: Text("Malay")),
              DropdownMenuItem(value: "Chinese", child: Text("Chinese")),
              DropdownMenuItem(value: "Tamil", child: Text("Tamil")),
            ],
            onChanged: (v) => setState(() => _language = v),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.date_range),
                  onPressed: _pickDate,
                  label: Text(
                    _date == null
                        ? "Select Date"
                        : "${_date!.year}-${_date!.month}-${_date!.day}",
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.access_time),
                  onPressed: _pickTime,
                  label: Text(_time == null ? "Select Time" : _time!.format(context)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          ElevatedButton.icon(
            icon: const Icon(Icons.search),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Searching caregivers... (prototype)")),
              );
            },
            label: const Text("Search Caregiver"),
          ),
          const SizedBox(height: 20),

          const _CaregiverCard(name: "Aunty Mei", years: 7),
          const _CaregiverCard(name: "Uncle Wong", years: 5),
        ],
      ),
    );
  }
}

class _CaregiverCard extends StatelessWidget {
  final String name;
  final int years;
  const _CaregiverCard({required this.name, required this.years});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.elderly)),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Experience: $years years"),
        trailing: ElevatedButton(
          onPressed: () {},
          child: const Text("Select"),
        ),
      ),
    );
  }
}
