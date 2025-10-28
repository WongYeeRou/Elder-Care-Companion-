import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class RegisterRolePage extends StatefulWidget {
  static const String route = '/register';
  const RegisterRolePage({super.key});
  @override
  State<RegisterRolePage> createState() => _RegisterRolePageState();
}

enum ECCRole { user, caregiver }

class _RegisterRolePageState extends State<RegisterRolePage> {
  ECCRole selected = ECCRole.user;

  Widget _roleButton(String text, ECCRole role) {
    final bool isSelected = selected == role;
    const mint = Color(0xFF33C7B6);
    return OutlinedButton(
      onPressed: () => setState(() => selected = role),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: mint, width: 1.5),
        minimumSize: const Size.fromHeight(48),
        backgroundColor: isSelected ? mint.withOpacity(.12) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(text, style: TextStyle(color: Colors.black87, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500)),
      ),
    );
  }

  void _goNext(BuildContext context) {
    if (selected == ECCRole.user) {
      Navigator.pushNamed(context, UserSignUpPage.route);
    } else {
      Navigator.pushNamed(context, CaregiverSignUpStub.route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Shell(
      titleTop: 'ElderCare',
      titleBottom: 'Companion',
      subtitle: 'Create your account',
      children: [
        _roleButton('User', ECCRole.user),
        const SizedBox(height: 12),
        _roleButton('Caregiver', ECCRole.caregiver),
        const SizedBox(height: 18),
        ElevatedButton(onPressed: () => _goNext(context), child: const Text('Sign Up')),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Colors.black87),
              children: const [
                TextSpan(text: 'Already have an account? '),
                TextSpan(text: 'Login here', style: TextStyle(decoration: TextDecoration.underline, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/* ------------------------------- User Sign Up ------------------------------ */

class UserSignUpPage extends StatefulWidget {
  static const String route = '/register/user';
  const UserSignUpPage({super.key});
  @override
  State<UserSignUpPage> createState() => _UserSignUpPageState();
}

class _UserSignUpPageState extends State<UserSignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _contact = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _contact.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signed up successfully (prototype)')));
    Navigator.popUntil(context, ModalRoute.withName('/'));
  }

  @override
  Widget build(BuildContext context) {
    return _Shell(
      titleTop: 'ElderCare',
      titleBottom: 'Companion',
      subtitle: 'Create your account',
      children: [
        AbsorbPointer(
          absorbing: true,
          child: TextField(controller: TextEditingController(text: 'User'), decoration: const InputDecoration()),
        ),
        const SizedBox(height: 12),
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(controller: _username, decoration: const InputDecoration(labelText: 'Username'), validator: _req),
              const SizedBox(height: 12),
              TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email Address'), validator: _emailVal),
              const SizedBox(height: 12),
              TextFormField(controller: _contact, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Contact Number'), validator: _phoneVal),
              const SizedBox(height: 12),
              TextFormField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Password'), validator: _pwdVal),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirm,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm Password'),
                validator: (v) => v != _password.text ? 'Passwords do not match' : null,
              ),
              const SizedBox(height: 18),
              ElevatedButton(onPressed: _submit, child: const Text('Sign Up')),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Colors.black87),
                    children: [
                      const TextSpan(text: 'Already have an account? '),
                      TextSpan(
                        text: 'Login here',
                        style: const TextStyle(decoration: TextDecoration.underline, fontWeight: FontWeight.w600),
                        recognizer: TapGestureRecognizer()..onTap = () => Navigator.popUntil(context, ModalRoute.withName('/')),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;
  String? _emailVal(String? v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null;
  String? _phoneVal(String? v) => (v == null || v.trim().length < 7) ? 'Enter a valid number' : null;
  String? _pwdVal(String? v) => (v == null || v.length < 6) ? 'Min 6 characters' : null;
}

/* --------------------------- Caregiver Sign Up stub --------------------------- */
class CaregiverSignUpStub extends StatelessWidget {
  static const String route = '/register/caregiver';
  const CaregiverSignUpStub({super.key});

  @override
  Widget build(BuildContext context) {
    return _Shell(
      titleTop: 'ElderCare',
      titleBottom: 'Companion',
      subtitle: 'Caregiver sign up (coming next)',
      children: [
        const Text('We will add fields for ID/license upload and verification in the next step.', textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Back')),
      ],
    );
  }
}

/* ------------------------------ Local shell widget ------------------------------ */
class _Shell extends StatelessWidget {
  final String titleTop;
  final String titleBottom;
  final String? subtitle;
  final List<Widget> children;
  const _Shell({required this.titleTop, required this.titleBottom, this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Text(titleTop, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w600, height: 1.1), textAlign: TextAlign.center),
                  Text(titleBottom, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w600, height: 1.1), textAlign: TextAlign.center),
                  if (subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(subtitle!, textAlign: TextAlign.center, style: TextStyle(color: Colors.black.withOpacity(.7))),
                  ],
                  const SizedBox(height: 24),
                  ...children,
                  const SizedBox(height: 16),
                  Center(child: Opacity(opacity: .75, child: Text('Terms of use. Privacy Policy', style: Theme.of(context).textTheme.bodySmall))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
