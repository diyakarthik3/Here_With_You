import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  StorageService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  Future<String> uploadAdminBytes({
    required String adminUid,
    required String folder,
    required String fileName,
    required Uint8List bytes,
    String? contentType,
  }) async {
    final sanitizedFileName = fileName.replaceAll(
      RegExp(r'[^A-Za-z0-9._-]'),
      '_',
    );
    final fileId = DateTime.now().microsecondsSinceEpoch;
    final path = 'admins/$adminUid/$folder/$fileId-$sanitizedFileName';

    final ref = _storage.ref().child(path);
    final metadata = contentType == null
        ? null
        : SettableMetadata(contentType: contentType);
    await ref.putData(bytes, metadata);
    return ref.getDownloadURL();
  }

  Future<String> uploadAdminFilePath({
    required String adminUid,
    required String folder,
    required String fileName,
    required String filePath,
    String? contentType,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('File path uploads are not supported on web.');
    }

    final bytes = await File(filePath).readAsBytes();
    return uploadAdminBytes(
      adminUid: adminUid,
      folder: folder,
      fileName: fileName,
      bytes: bytes,
      contentType: contentType,
    );
  }

  Future<void> deleteByDownloadUrl(String? url) async {
    if (url == null || url.trim().isEmpty) {
      return;
    }
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {
      // Ignore deletion failures for already-removed files.
    }
  }

  Future<List<String>> fetchLinkedAdminPuzzleImageUrls() async {
    final user = _auth.currentUser;
    final email = user?.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) {
      return const [];
    }

    final linkDoc = await _firestore
        .collection('player_links')
        .doc(email)
        .get();
    final adminUid = linkDoc.data()?['adminUid'] as String?;
    if (adminUid == null || adminUid.isEmpty) {
      return const [];
    }

    final snapshot = await _firestore
        .collection('admins')
        .doc(adminUid)
        .collection('media_assets')
        .orderBy('createdAt', descending: false)
        .get();

    final urls = <String>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final urlCandidates = [
        data['downloadUrl'] as String?,
        data['imageUrl'] as String?,
        data['url'] as String?,
        data['storageUrl'] as String?,
      ];

      final directUrl = urlCandidates
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .cast<String?>()
          .firstWhere((value) => value != null, orElse: () => null);

      if (directUrl != null) {
        urls.add(directUrl);
      }
    }

    return urls.toSet().toList(growable: false);
  }
}
