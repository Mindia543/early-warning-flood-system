import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.location,
    required this.alertsEnabled,
    this.isAdmin = false,
  });

  final String id;
  final String email;
  final String displayName;
  final String location;
  final bool alertsEnabled;
  final bool isAdmin;

  factory AppUser.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return AppUser(
      id: snapshot.id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      location: data['location'] as String? ?? '',
      alertsEnabled: data['alertsEnabled'] as bool? ?? true,
      // Admin status is authoritative from a custom claim, not this field.
      isAdmin: false,
    );
  }

  Map<String, Object?> toFirestore() => {
    'email': email,
    'displayName': displayName,
    'location': location,
    'alertsEnabled': alertsEnabled,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}
