import 'package:flutter/material.dart';
import 'login.dart';
import 'register.dart';
import 'forgot_password.dart';
import 'user_home.dart';
import 'user_booking_page.dart';

void main() => runApp(const ECCApp());

class ECCApp extends StatelessWidget {
  const ECCApp({super.key});

  static const Color mint = Color(0xFF33C7B6);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ElderCare Companion',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: mint),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(width: 1.5),
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(6)),
            borderSide: BorderSide(color: mint, width: 1.5),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(6)),
            borderSide: BorderSide(color: mint, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: mint,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      home: const LoginPage(),
      routes: {
        // register pages
        RegisterRolePage.route: (_) => const RegisterRolePage(),
        UserSignUpPage.route: (_) => const UserSignUpPage(),
        CaregiverSignUpStub.route: (_) => const CaregiverSignUpStub(),

        // forgot password
        ForgotPasswordPage.route: (_) => const ForgotPasswordPage(),

        // user home
        UserHomeShell.route: (_) => const UserHomeShell(),

        // booking system
        '/booking': (_) => const BookingPage(),

      },
    );
  }
}
