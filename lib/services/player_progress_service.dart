import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PlayerProgressService {
  PlayerProgressService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>>? _progressDoc() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return null;
    }

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('progress')
        .doc('rewards');
  }

  Future<int> fetchHighestCompletedLevel() async {
    final docRef = _progressDoc();
    if (docRef == null) {
      return 0;
    }

    final snapshot = await docRef.get();
    return (snapshot.data()?['highestCompletedLevel'] as num?)?.toInt() ?? 0;
  }

  Future<void> markLevelCompleted(int level) async {
    final docRef = _progressDoc();
    if (docRef == null) {
      throw StateError('Player user is not signed in.');
    }

    final currentLevel = await fetchHighestCompletedLevel();
    if (level <= currentLevel) {
      return;
    }

    await docRef.set({
      'highestCompletedLevel': level,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
