// lib/booking_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class BookingRequestData {
  final String userUid;
  final String caregiverUid;

  final String clientName;
  final String clientEmail;
  final String clientContact;

  final String recipientFullName;
  final String recipientGender;
  final String recipientContact;
  final String recipientRelationship;
  final String recipientAge;
  final String recipientAddress;

  final String checkupType;
  final String clinicAddress;

  final DateTime startAt;
  final DateTime endAt;
  final double estDurationHours;
  final double ratePerHour;
  final double estTotal;
  final String notes;

  BookingRequestData({
    required this.userUid,
    required this.caregiverUid,
    required this.clientName,
    required this.clientEmail,
    required this.clientContact,
    required this.recipientFullName,
    required this.recipientGender,
    required this.recipientContact,
    required this.recipientRelationship,
    required this.recipientAge,
    required this.recipientAddress,
    required this.checkupType,
    required this.clinicAddress,
    required this.startAt,
    required this.endAt,
    required this.estDurationHours,
    required this.ratePerHour,
    required this.estTotal,
    required this.notes,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'userUid': userUid,
      'caregiverUid': caregiverUid,
      'client': {
        'name': clientName,
        'email': clientEmail,
        'contact': clientContact,
      },
      'recipient': {
        'fullName': recipientFullName,
        'gender': recipientGender,
        'contact': recipientContact,
        'relationship': recipientRelationship,
        'age': recipientAge,
        'address': recipientAddress,
      },
      'checkupType': checkupType,
      'clinicAddress': clinicAddress,
      'startAt': Timestamp.fromDate(startAt),
      'endAt': Timestamp.fromDate(endAt),
      'estDurationHours': estDurationHours,
      'ratePerHour': ratePerHour,
      'estTotal': estTotal,
      'notes': notes,
      'status': 'awaiting_payment',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

double computeEstHours(DateTime startAt, DateTime endAt) {
  final ms = endAt.millisecondsSinceEpoch - startAt.millisecondsSinceEpoch;
  final raw = ms / (1000 * 60 * 60);
  // minimum 2h and round to nearest 0.5h like in your design
  final rounded = (raw / 0.5).round() * 0.5;
  return rounded < 2.0 ? 2.0 : rounded;
}
