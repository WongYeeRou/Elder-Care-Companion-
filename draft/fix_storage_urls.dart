import 'package:cloud_firestore/cloud_firestore.dart';

String normalizeStorageUrl(String? u) {
  if (u == null) return '';
  final re = RegExp(r'(/v0/b/)([^/]+)\.firebasestorage\.app(/o/)');
  var s = u.replaceAll('"', '');
  return s.replaceFirstMapped(re, (m) => '${m[1]}${m[2]}.appspot.com${m[3]}');
}

Future<void> fixCaregiverUrlsOnce() async {
  final q = await FirebaseFirestore.instance.collection('caregivers').get();
  for (final doc in q.docs) {
    final data = doc.data();
    Map<String, dynamic> att = Map<String, dynamic>.from(data['attachments'] ?? {});
    bool changed = false;

    List<String> fixList(List? xs) {
      final out = <String>[];
      for (final x in (xs ?? const [])) {
        final s = normalizeStorageUrl(x as String?);
        out.add(s);
      }
      return out;
    }

    final certs = fixList(att['certificates']);
    final dls   = fixList(att['drivingLicenses']);
    final ics   = fixList(att['idCards']);
    final pic   = normalizeStorageUrl(att['profilePic']);

    final newAtt = {
      'certificates': certs,
      'drivingLicenses': dls,
      'idCards': ics,
      'profilePic': pic,
    };

    if (newAtt.toString() != att.toString()) {
      await doc.reference.update({'attachments': newAtt});
      print('✅ Updated ${doc.id}');
    }
  }
}
