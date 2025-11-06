import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img; // for real compression on web

class CaregiverSignUpPage extends StatefulWidget {
  static const route = '/register/caregiver';
  const CaregiverSignUpPage({super.key});
  @override
  State<CaregiverSignUpPage> createState() => _CaregiverSignUpPageState();
}

class _CaregiverSignUpPageState extends State<CaregiverSignUpPage> {
  final PageController _pager = PageController();
  int _step = 0;

  // Step 1
  final _f1 = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _contact = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  // Step 2 (attachments)
  final _f2 = GlobalKey<FormState>();
  final _ratePerHour = TextEditingController();
  final _picker = ImagePicker();
  final List<XFile> _certFiles = [];
  final List<XFile> _dlFiles = [];
  final List<XFile> _icFiles = [];
  XFile? _profileFile;

  // Step 3
  final _f3 = GlobalKey<FormState>();
  final _yearsExp = TextEditingController();
  String? _region;
  String? _language;
  String? _gender;

  final _days = const ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
  final Map<String, bool> _dayOn = {
    'Monday': false, 'Tuesday': false, 'Wednesday': false, 'Thursday': false,
    'Friday': false, 'Saturday': false, 'Sunday': false,
  };
  final Map<String, TimeOfDay?> _start = {};
  final Map<String, TimeOfDay?> _end = {};

  bool _busy = false;
  String _status = '';

  @override
  void dispose() {
    _pager.dispose();
    _fullName.dispose();
    _email.dispose();
    _contact.dispose();
    _password.dispose();
    _confirm.dispose();
    _ratePerHour.dispose();
    _yearsExp.dispose();
    super.dispose();
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  void _setBusy(String s) {
    if (!mounted) return;
    setState(() { _busy = true; _status = s; });
  }

  void _next() {
    if (_step == 0 && !(_f1.currentState?.validate() ?? false)) return;
    if (_step == 1 && !(_f2.currentState?.validate() ?? false)) return;
    if (_step < 2) {
      setState(() => _step += 1);
      _pager.nextPage(duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step -= 1);
      _pager.previousPage(duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _pickStart(String day) async {
    final res = await showTimePicker(
      context: context,
      initialTime: _start[day] ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (res != null) setState(() => _start[day] = res);
  }

  Future<void> _pickEnd(String day) async {
    final res = await showTimePicker(
      context: context,
      initialTime: _end[day] ?? const TimeOfDay(hour: 17, minute: 0),
    );
    if (res != null) setState(() => _end[day] = res);
  }

  void _toggleDay(String day, bool v) => setState(() => _dayOn[day] = v);

  Future<void> _pickMultiInto(List<XFile> list, {int max = 3}) async {
    if (list.length >= max) { _toast('Maximum $max files reached.'); return; }
    final imgs = await _picker.pickMultiImage(imageQuality: 85);
    if (imgs.isEmpty) return;
    final remaining = max - list.length;
    setState(() => list.addAll(imgs.take(remaining)));
  }

  Future<void> _pickSingleProfile() async {
    final imgx = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (imgx != null) setState(() => _profileFile = imgx);
  }

  /// Compress to JPEG (maxWidth ~1200px, quality 80). If decode fails, return original.
  Future<Uint8List> _compress(Uint8List input) async {
    try {
      final decoded = img.decodeImage(input);
      if (decoded == null) return input;
      final w = decoded.width;
      final maxW = 1200;
      final resized = w > maxW ? img.copyResize(decoded, width: maxW) : decoded;
      return Uint8List.fromList(img.encodeJpg(resized, quality: 80));
    } catch (_) {
      return input;
    }
  }

  Future<String?> _uploadOne(
      FirebaseStorage storage,
      String uid,
      String folder,
      XFile file, {
        Duration timeout = const Duration(seconds: 180), // more generous
      }) async {
    try {
      final filename = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final ref = storage.ref().child('caregivers/$uid/$folder/$filename');

      // Read + compress
      final raw = await file.readAsBytes();
      final bytes = await _compress(raw);

      final meta = SettableMetadata(contentType: 'image/jpeg');
      final snap = await ref.putData(bytes, meta).timeout(timeout);
      return await snap.ref.getDownloadURL();
    } on TimeoutException {
      _toast('Upload timed out for ${file.name}. Skipped.');
      return null;
    } on FirebaseException catch (e) {
      _toast('Upload error for ${file.name}: ${e.code}');
      return null;
    } catch (e) {
      _toast('Upload failed for ${file.name}: $e');
      return null;
    }
  }

  Future<List<String>> _uploadList(
      FirebaseStorage storage,
      String uid,
      String folder,
      List<XFile> files,
      ) async {
    final urls = <String>[];
    for (final f in files) {
      final url = await _uploadOne(storage, uid, folder, f);
      if (url != null) urls.add(url);
    }
    return urls;
  }

  Future<void> _submit() async {
    if (!(_f3.currentState?.validate() ?? false)) return;

    for (final d in _days) {
      if (_dayOn[d] == true && (_start[d] == null || _end[d] == null)) {
        _toast('Please set start & end time for $d');
        return;
      }
    }

    setState(() { _busy = true; _status = 'Creating account...'; });

    UserCredential? cred;
    final firestore = FirebaseFirestore.instance;

    try {
      // 1) Auth
      cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      final uid = cred.user!.uid;

      // 2) users/{uid}
      _setBusy('Saving user profile...');
      await firestore.collection('users').doc(uid).set({
        'username': _fullName.text.trim(),
        'email': _email.text.trim(),
        'contact': _contact.text.trim(),
        'role': 'caregiver',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3) caregivers/{uid} (minimal)
      _setBusy('Creating caregiver record...');
      // 3) caregivers/{uid} (minimal)
      await firestore.collection('caregivers').doc(uid).set({
        'fullName': _fullName.text.trim(),
        'email': _email.text.trim(),
        'contact': _contact.text.trim(),
        'yearsOfExperience': int.tryParse(_yearsExp.text.trim()) ?? 0,
        'region': _region,
        'language': _language,
        'gender': _gender,
        'ratePerHour': double.tryParse(_ratePerHour.text.trim()) ?? 0.0,
        'attachments': {
          'certificates': [],
          'drivingLicenses': [],
          'idCards': [],
          'profilePic': null,
        },
        'availability': {},
        'createdAt': FieldValue.serverTimestamp(),
        'role': 'caregiver',
        'status': 'pending',                //
        'rejectionReason': null,           // optional
        'approvedAt': null,                // optional
        'approvedBy': null,                // optional
      });


      // 4) Upload files (with timeouts & error handling)
      _setBusy('Uploading files...');
      final storage = FirebaseStorage.instance;

      final certUrls = await _uploadList(storage, uid, 'certificates', _certFiles);
      final dlUrls   = await _uploadList(storage, uid, 'driving_licenses', _dlFiles);
      final icUrls   = await _uploadList(storage, uid, 'ic_cards', _icFiles);
      String? profileUrl;
      if (_profileFile != null) {
        profileUrl = await _uploadOne(storage, uid, 'profile', _profileFile!);
      }

      // 5) Availability
      final df = DateFormat('HH:mm');
      final availability = <String, dynamic>{};
      for (final d in _days) {
        if (_dayOn[d] == true) {
          final st = _start[d]!;
          final en = _end[d]!;
          availability[d] = {
            'start': df.format(DateTime(0, 1, 1, st.hour, st.minute)),
            'end'  : df.format(DateTime(0, 1, 1, en.hour, en.minute)),
          };
        }
      }

      // 6) Final update
      _setBusy('Finalizing...');
      await firestore.collection('caregivers').doc(uid).update({
        'attachments': {
          'certificates': certUrls,
          'drivingLicenses': dlUrls,
          'idCards': icUrls,
          'profilePic': profileUrl,
        },
        'availability': availability,
      });

      if (!mounted) return;
      _toast('Caregiver account created!');
      Navigator.popUntil(context, ModalRoute.withName('/'));
    } on FirebaseException catch (e) {
      _toast('Firebase error: ${e.code} — ${e.message ?? ''}'.trim());
      try { await cred?.user?.delete(); } catch (_) {}
    } catch (e) {
      _toast('Failed to save caregiver profile: $e');
      try { await cred?.user?.delete(); } catch (_) {}
    } finally {
      if (!mounted) return;
      setState(() { _busy = false; _status = ''; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final nextText = _step < 2 ? 'Next' : 'Sign Up';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Caregiver Sign Up'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _back),
      ),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _busy,
          child: Stack(
            children: [
              PageView(
                controller: _pager,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _Step1Basic(formKey: _f1, fullName: _fullName, email: _email,
                      contact: _contact, password: _password, confirm: _confirm),
                  _Step2Attachments(
                    formKey: _f2, ratePerHour: _ratePerHour,
                    certFiles: _certFiles, dlFiles: _dlFiles, icFiles: _icFiles,
                    profileFile: _profileFile,
                    addCerts: () => _pickMultiInto(_certFiles, max: 3),
                    addDLs: () => _pickMultiInto(_dlFiles, max: 3),
                    addICs: () => _pickMultiInto(_icFiles, max: 3),
                    addProfile: _pickSingleProfile,
                    removeCertAt: (i) => setState(() => _certFiles.removeAt(i)),
                    removeDLAt: (i) => setState(() => _dlFiles.removeAt(i)),
                    removeICAt: (i) => setState(() => _icFiles.removeAt(i)),
                    clearProfile: () => setState(() => _profileFile = null),
                  ),
                  _Step3Details(
                    formKey: _f3, yearsExp: _yearsExp,
                    region: _region, onRegion: (v) => setState(() => _region = v),
                    language: _language, onLanguage: (v) => setState(() => _language = v),
                    gender: _gender, onGender: (v) => setState(() => _gender = v),
                    dayOn: _dayOn, start: _start, end: _end,
                    pickStart: _pickStart, pickEnd: _pickEnd,
                    onToggleDay: _toggleDay,
                  ),
                ],
              ),
              if (_busy) const Positioned.fill(child: ColoredBox(color: Colors.black12)),
              if (_busy)
                Positioned.fill(
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      if (_status.isNotEmpty) Text(_status),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(children: [
            Expanded(child: OutlinedButton(onPressed: _back, child: const Text('<  Back'))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(onPressed: _step < 2 ? _next : _submit, child: Text(nextText))),
          ]),
        ),
      ),
    );
  }
}

/* ------------------------ Step UIs ----------------------- */

class _Step1Basic extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController fullName, email, contact, password, confirm;
  const _Step1Basic({
    required this.formKey,
    required this.fullName,
    required this.email,
    required this.contact,
    required this.password,
    required this.confirm,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      children: [
        const SizedBox(height: 8),
        Center(child: Column(children: const [
          Text('ElderCare', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.1)),
          Text('Companion', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.1)),
        ])),
        const SizedBox(height: 14),
        AbsorbPointer(absorbing: true, child: TextField(controller: TextEditingController(text: 'Caregiver'))),
        const SizedBox(height: 12),
        Form(
          key: formKey,
          child: Column(children: [
            TextFormField(controller: fullName, decoration: const InputDecoration(labelText: 'Full Name'), validator: _req),
            const SizedBox(height: 12),
            TextFormField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email Address'),
                validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null),
            const SizedBox(height: 12),
            TextFormField(controller: contact, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Contact Number'), validator: _req),
            const SizedBox(height: 12),
            TextFormField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password'),
                validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null),
            const SizedBox(height: 12),
            TextFormField(controller: confirm, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm Password'),
                validator: (v) => (v == password.text) ? null : 'Passwords do not match'),
          ]),
        ),
      ],
    );
  }
  static String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;
}

class _Step2Attachments extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController ratePerHour;
  final List<XFile> certFiles, dlFiles, icFiles;
  final XFile? profileFile;
  final VoidCallback addCerts, addDLs, addICs, addProfile, clearProfile;
  final void Function(int) removeCertAt, removeDLAt, removeICAt;

  const _Step2Attachments({
    required this.formKey,
    required this.ratePerHour,
    required this.certFiles,
    required this.dlFiles,
    required this.icFiles,
    required this.profileFile,
    required this.addCerts,
    required this.addDLs,
    required this.addICs,
    required this.addProfile,
    required this.removeCertAt,
    required this.removeDLAt,
    required this.removeICAt,
    required this.clearProfile,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      children: [
        const SizedBox(height: 8),
        const _HeaderLabel('Caregiver'),
        const SizedBox(height: 12),
        _AttachCard(
          title: 'Certificate / License (max 3)',
          items: certFiles.map((e) => e.name).toList(),
          onAdd: addCerts, onRemove: removeCertAt, hint: 'Accepted: .jpg .jpeg .png',
        ),
        const SizedBox(height: 12),
        _AttachCard(
          title: 'Driving License (max 3)',
          items: dlFiles.map((e) => e.name).toList(),
          onAdd: addDLs, onRemove: removeDLAt, hint: 'Accepted: .jpg .jpeg .png',
        ),
        const SizedBox(height: 12),
        _AttachCard(
          title: 'IC (front & back) (max 3)',
          items: icFiles.map((e) => e.name).toList(),
          onAdd: addICs, onRemove: removeICAt, hint: 'Accepted: .jpg .jpeg .png',
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(child: Text('Profile Picture', style: TextStyle(fontWeight: FontWeight.w600))),
                IconButton(onPressed: addProfile, icon: const Icon(Icons.add_a_photo_outlined)),
              ]),
              const SizedBox(height: 6),
              if (profileFile == null)
                Text('Accepted: .jpg .jpeg .png (1 file)', style: TextStyle(color: Colors.black.withOpacity(.6)))
              else
                ListTile(
                  dense: true, contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.image), title: Text(profileFile!.name),
                  trailing: IconButton(icon: const Icon(Icons.close), onPressed: clearProfile),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Form(
          key: formKey,
          child: TextFormField(
            controller: ratePerHour,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Rate per Hour (RM)'),
            validator: (v) {
              final n = double.tryParse((v ?? '').trim());
              if (n == null || n <= 0) return 'Enter a valid rate';
              return null;
            },
          ),
        ),
      ],
    );
  }
}

class _AttachCard extends StatelessWidget {
  final String title; final List<String> items;
  final VoidCallback onAdd; final void Function(int) onRemove; final String hint;
  const _AttachCard({super.key, required this.title, required this.items, required this.onAdd, required this.onRemove, required this.hint});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
            IconButton(onPressed: onAdd, icon: const Icon(Icons.add_circle_outline)),
          ]),
          const SizedBox(height: 6),
          if (items.isEmpty) Text(hint, style: TextStyle(color: Colors.black.withOpacity(.6))) else
            ...List.generate(items.length, (i) => ListTile(
              dense: true, contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.attachment), title: Text(items[i]),
              trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => onRemove(i)),
            )),
        ]),
      ),
    );
  }
}

class _Step3Details extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController yearsExp;
  final String? region, language, gender;
  final ValueChanged<String?> onRegion, onLanguage, onGender;
  final Map<String, bool> dayOn; final Map<String, TimeOfDay?> start, end;
  final Future<void> Function(String) pickStart, pickEnd;
  final void Function(String day, bool value) onToggleDay;

  const _Step3Details({
    required this.formKey, required this.yearsExp,
    required this.region, required this.onRegion,
    required this.language, required this.onLanguage,
    required this.gender, required this.onGender,
    required this.dayOn, required this.start, required this.end,
    required this.pickStart, required this.pickEnd,
    required this.onToggleDay,
  });

  @override
  Widget build(BuildContext context) {
    final days = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      children: [
        const _HeaderLabel('Caregiver'),
        const SizedBox(height: 12),
        Form(
          key: formKey,
          child: Column(children: [
            TextFormField(
              controller: yearsExp, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Years of Experience'),
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                if (n == null || n < 0) return 'Enter a valid number';
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: region, decoration: const InputDecoration(labelText: 'Select Region in Penang'),
              items: const [
                DropdownMenuItem(value: 'George Town', child: Text('George Town')),
                DropdownMenuItem(value: 'Bayan Lepas', child: Text('Bayan Lepas')),
                DropdownMenuItem(value: 'Butterworth', child: Text('Butterworth')),
              ],
              onChanged: onRegion, validator: (v) => v == null ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: language, decoration: const InputDecoration(labelText: 'Select Your Preferred Language'),
              items: const [
                DropdownMenuItem(value: 'English', child: Text('English')),
                DropdownMenuItem(value: 'Malay', child: Text('Malay')),
                DropdownMenuItem(value: 'Chinese', child: Text('Chinese')),
                DropdownMenuItem(value: 'Tamil', child: Text('Tamil')),
              ],
              onChanged: onLanguage, validator: (v) => v == null ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: gender, decoration: const InputDecoration(labelText: 'Select Your Gender'),
              items: const [
                DropdownMenuItem(value: 'Male', child: Text('Male')),
                DropdownMenuItem(value: 'Female', child: Text('Female')),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              onChanged: onGender, validator: (v) => v == null ? 'Required' : null,
            ),
            const SizedBox(height: 12),
          ]),
        ),
        const SizedBox(height: 6),
        Text('Select Available Schedule:',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ...days.map((d) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            SizedBox(
              width: 110,
              child: Row(children: [
                Checkbox(value: dayOn[d] ?? false, onChanged: (v) => onToggleDay(d, v ?? false)),
                Flexible(child: Text(d)),
              ]),
            ),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(
              onPressed: (dayOn[d] ?? false) ? () => pickStart(d) : null,
              child: Text(start[d] == null ? 'Start Time' : start[d]!.format(context)),
            )),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(
              onPressed: (dayOn[d] ?? false) ? () => pickEnd(d) : null,
              child: Text(end[d] == null ? 'End Time' : end[d]!.format(context)),
            )),
          ]),
        )),
      ],
    );
  }
}

class _HeaderLabel extends StatelessWidget {
  final String text;
  const _HeaderLabel(this.text);
  @override
  Widget build(BuildContext context) =>
      Text(text, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700));
}
