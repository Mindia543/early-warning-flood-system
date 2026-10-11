import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import '../models/flood_warning.dart';

class DatabaseService {
  DatabaseService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _warnings =>
      _firestore.collection('warnings');

  Future<void> createOrUpdateUserProfile({
    required String displayName,
    required String location,
    required bool alertsEnabled,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('You must be signed in.');

    final profile = AppUser(
      id: user.uid,
      email: user.email ?? '',
      displayName: displayName.trim(),
      location: location.trim(),
      alertsEnabled: alertsEnabled,
    );
    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(profile.toFirestore(), SetOptions(merge: true));
  }

  Stream<AppUser?> watchCurrentUserProfile() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map(
          (snapshot) => snapshot.exists ? AppUser.fromSnapshot(snapshot) : null,
        );
  }

  Stream<List<FloodWarning>> watchActiveWarnings() {
    return _warnings
        .where('status', isEqualTo: WarningStatus.published.name)
        .where('expiryTime', isGreaterThan: Timestamp.now())
        .orderBy('expiryTime')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(FloodWarning.fromSnapshot)
              .where((warning) => warning.isActive)
              .toList(),
        );
  }

  Stream<List<FloodWarning>> watchWarningHistory() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(const <FloodWarning>[]);
    return _warnings
        .where(
          'status',
          whereIn: [
            WarningStatus.published.name,
            WarningStatus.expired.name,
            WarningStatus.cancelled.name,
          ],
        )
        .orderBy('issueTime', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(FloodWarning.fromSnapshot).toList(),
        );
  }

  Future<String> createDraftWarning(FloodWarning warning) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('You must be signed in.');
    if (warning.title.trim().isEmpty || warning.affectedArea.trim().isEmpty) {
      throw ArgumentError('Title and affected area are required.');
    }
    final reference = await _warnings.add({
      ...warning.toFirestore(),
      'status': WarningStatus.draft.name,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': user.uid,
    });
    return reference.id;
  }

  /// Publishing is intentionally a server-side operation. The callable
  /// function checks the administrator custom claim before changing status.
  Future<void> saveDeviceToken({
    required String token,
    required String platform,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('You must be signed in.');
    if (token.trim().isEmpty) {
      throw ArgumentError('A device token is required.');
    }
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('devices')
        .doc(_stableTokenDocumentId(token))
        .set({
          'token': token,
          'platform': platform,
          'enabled': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> disableDeviceToken(String token) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('devices')
        .doc(_stableTokenDocumentId(token))
        .update({'enabled': false, 'updatedAt': FieldValue.serverTimestamp()});
  }

  String _stableTokenDocumentId(String token) {
    // FCM tokens are not suitable as Firestore document IDs because they may
    // contain characters that make IDs awkward to inspect. A deterministic,
    // non-secret key also makes token refreshes idempotent.
    var hash = 0;
    for (final codeUnit in token.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return 'token_$hash';
  }
}
