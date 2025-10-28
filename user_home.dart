import 'package:flutter/material.dart';
import 'user_booking_page.dart';

class UserHomeShell extends StatefulWidget {
  static const route = '/user';
  const UserHomeShell({super.key});

  @override
  State<UserHomeShell> createState() => _UserHomeShellState();
}

class _UserHomeShellState extends State<UserHomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const _HomeDashboard(),
      const BookingPage(),
      const _StubPage(title: 'Messages'),
      const _StubPage(title: 'Profile'),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event), label: 'Booking'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Welcome, User', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              ),
              IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none), tooltip: 'Notifications'),
            ],
          ),
          const SizedBox(height: 8),

          _SectionTitle('My Favourite Caregiver'),
          const SizedBox(height: 8),
          const _CaregiverCard(name: 'Aunty Mei', years: 7, rating: 4.5, badge: '⭐️⭐️⭐️⭐️☆'),
          const SizedBox(height: 16),

          _SectionTitle('My Care Recipient'),
          const SizedBox(height: 8),
          Row(
            children: const [
              Expanded(child: _RecipientCard(name: 'Grandma Lee', age: 78)),
              SizedBox(width: 12),
              Expanded(child: _RecipientCard(name: 'Uncle Tan', age: 71)),
            ],
          ),
          const SizedBox(height: 16),

          _SectionTitle('My Booking'),
          const SizedBox(height: 8),
          const _BookingStrip(),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700));
}

class _CaregiverCard extends StatelessWidget {
  final String name;
  final int years;
  final double rating;
  final String badge;
  const _CaregiverCard({required this.name, required this.years, required this.rating, required this.badge});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          children: [
            const CircleAvatar(radius: 28, child: Icon(Icons.elderly)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('Years of Experience: $years'),
                  const SizedBox(height: 4),
                  Row(children: [const Icon(Icons.star, size: 16, color: Colors.amber), const SizedBox(width: 4), Text('$rating  $badge')]),
                ],
              ),
            ),
            IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz)),
          ],
        ),
      ),
    );
  }
}

class _RecipientCard extends StatelessWidget {
  final String name;
  final int age;
  const _RecipientCard({required this.name, required this.age});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          children: [
            const CircleAvatar(radius: 22, child: Icon(Icons.face)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('Age: $age'),
            ]),
          ],
        ),
      ),
    );
  }
}

class _BookingStrip extends StatelessWidget {
  const _BookingStrip();

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> items = [
      {'date': '2025-08-01', 'time': '10:00', 'status': 'In-Progress'},
      {'date': '2025-08-07', 'time': '09:30', 'status': 'Upcoming'},
      {'date': '2025-08-15', 'time': '11:15', 'status': 'Completed'},
      {'date': '2025-08-20', 'time': '08:00', 'status': 'Upcoming'},
    ];

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final it = items[i];
          return Container(
            width: 160,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(ctx).colorScheme.primary.withOpacity(.4)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Date: ${it['date']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('Time: ${it['time']}'),
                const Spacer(),
                Row(children: [const Text('Status: '), Chip(label: Text(it['status']!), visualDensity: VisualDensity.compact, padding: EdgeInsets.zero)]),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StubPage extends StatelessWidget {
  final String title;
  const _StubPage({required this.title});
  @override
  Widget build(BuildContext context) => Center(child: Text(title, style: Theme.of(context).textTheme.headlineSmall));
}
