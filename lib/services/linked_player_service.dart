import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LinkedPlayerRecord {
  final String name;
  final String email;
  final String adminUid;
  final DateTime? createdAt;

  const LinkedPlayerRecord({
    required this.name,
    required this.email,
    required this.adminUid,
    required this.createdAt,
  });

  factory LinkedPlayerRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return LinkedPlayerRecord(
      name: (data['name'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      adminUid: (data['adminUid'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class LinkedPlayerService {
  LinkedPlayerService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  CollectionReference<Map<String, dynamic>> _linkedPlayerFeed(String adminUid) {
    return _firestore.collection('admins').doc(adminUid).collection('linked_player_feed');
  }

  Future<void> addLinkedPlayer({required String name, required String email}) async {
    final admin = _auth.currentUser;
    if (admin == null) {
      throw StateError('Admin user is not signed in.');
    }

    final normalizedEmail = _normalizeEmail(email);
    final payload = {
      'name': name.trim(),
      'email': normalizedEmail,
      'adminUid': admin.uid,
      'adminEmail': admin.email?.trim().toLowerCase(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    // Write to admin's feed (for the manage-profile list view).
    await _linkedPlayerFeed(admin.uid).doc(normalizedEmail).set(
      payload,
      SetOptions(merge: true),
    );

    // Also write to top-level collection so the player lookup
    // works with a direct document read (no collection-group index needed).
    await _firestore
        .collection('player_links')
        .doc(normalizedEmail)
        .set(payload, SetOptions(merge: true));
  }

  Stream<List<LinkedPlayerRecord>> linkedPlayersForCurrentAdmin() {
    final admin = _auth.currentUser;
    if (admin == null) {
      return Stream.value(const <LinkedPlayerRecord>[]);
    }

    return _linkedPlayerFeed(admin.uid).orderBy('createdAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs.map(LinkedPlayerRecord.fromDoc).toList(),
        );
  }

  Future<bool> isCurrentUserLinked() async {
    final user = _auth.currentUser;
    final email = user?.email?.trim().toLowerCase();

    if (email == null || email.isEmpty) {
      return false;
    }

    // Fast path: direct document read on the top-level player_links collection.
    // This requires no Firestore index and works immediately after the admin
    // calls addLinkedPlayer().
    try {
      final doc = await _firestore.collection('player_links').doc(email).get();
      if (doc.exists) {
        return true;
      }
    } catch (_) {
      // Fall through to legacy collectionGroup check below.
    }

    // Legacy path: collection-group query used by entries created before the
    // player_links collection was introduced. Requires the collection-group
    // index to be enabled in the Firebase Console for 'linked_player_feed'
    // on the 'email' field; silently returns false if the index is missing.
    try {
      final snapshot = await _firestore
          .collectionGroup('linked_player_feed')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}