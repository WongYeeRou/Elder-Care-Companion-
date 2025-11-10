import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'login.dart';
import 'register.dart';
import 'forgot_password.dart';
import 'user_home.dart';
import 'user_booking_page.dart';
import 'caregiver_signup.dart';
import 'caregiver_gate.dart';
import 'caregiver_home.dart';
import 'caregiver_bookings.dart';
import 'payment_cash_in_page.dart';
import 'admin_payments_approve_page.dart';
import 'admin_shell.dart';
import 'admin_user_request_detail.dart';
import 'caregiver_ongoing_actions.dart';
import 'payment_additional_page.dart';

// Optional: details page if you kept it
import 'user_view_caregiver_detail.dart';
import 'user_make_booking.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ECCApp());
}

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
        // auth & register
        RegisterRolePage.route: (_) => const RegisterRolePage(),
        UserSignUpPage.route: (_) => const UserSignUpPage(),
        CaregiverSignUpPage.route: (_) => const CaregiverSignUpPage(),
        ForgotPasswordPage.route: (_) => const ForgotPasswordPage(),

        // user
        UserHomeShell.route: (_) => const UserHomeShell(),
        BookingPage.route: (_) => const BookingPage(),
        CaregiverDetailPage.route: (_) => const CaregiverDetailPage(),
        UserMakeBookingPage.route: (_) => const UserMakeBookingPage(),
        PaymentCashInPage.route: (_) => const PaymentCashInPage(),
        AdminPaymentsApprovePage.route: (_) => const AdminPaymentsApprovePage(),
        PaymentAdditionalPage.route: (_) => const PaymentAdditionalPage(),
        CaregiverBookingsPage.route: (context) => const CaregiverBookingsPage(),



        // caregiver
        '/caregiver': (_) => const CaregiverGate(),
        CaregiverHome.route: (_) => const CaregiverHome(),

        // ADMIN — point /admin to the SHELL (bottom bar)
        AdminShell.route: (_) => const AdminShell(),
        // If AdminShell.route is '/admin', you do NOT need another '/admin' below.

        // login
        '/login': (_) => const LoginPage(),
      },
    );
  }
}
