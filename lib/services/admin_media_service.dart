import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:here_with_you/services/storage_service.dart';

enum MediaUploadSource { cameraRoll, localFiles, googlePhotos }

class UploadedMediaFile {
  final String id;
  final String fileName;
  final MediaUploadSource source;
  final Uint8List? bytes;
  final String? downloadUrl;
  final String? originalPath;
  final DateTime createdAt;

  const UploadedMediaFile({
    required this.id,
    required this.fileName,
    required this.source,
    this.bytes,
    this.downloadUrl,
    this.originalPath,
    required this.createdAt,
  });
}

class MixAndMatchPairRecord {
  final String id;
  final String imageName;
  final Uint8List imageBytes;
  final String? imageUrl;
  final String description;
  final DateTime createdAt;

  const MixAndMatchPairRecord({
    required this.id,
    required this.imageName,
    required this.imageBytes,
    this.imageUrl,
    required this.description,
    required this.createdAt,
  });
}

class AdminMediaService {
  AdminMediaService._({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  static final AdminMediaService instance = AdminMediaService._();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final StorageService _storageService = StorageService();

  final ValueNotifier<List<UploadedMediaFile>> uploadedFiles =
      ValueNotifier<List<UploadedMediaFile>>([]);
  final ValueNotifier<List<MixAndMatchPairRecord>> mixAndMatchPairs =
      ValueNotifier<List<MixAndMatchPairRecord>>([]);

  CollectionReference<Map<String, dynamic>>? _mediaCollection() {
    final admin = _auth.currentUser;
    if (admin == null) {
      return null;
    }

    return _firestore
        .collection('admins')
        .doc(admin.uid)
        .collection('media_assets');
  }

  CollectionReference<Map<String, dynamic>>? _mixAndMatchCollection() {
    final admin = _auth.currentUser;
    if (admin == null) {
      return null;
    }

    return _firestore
        .collection('admins')
        .doc(admin.uid)
        .collection('mix_and_match_pairs');
  }

  MediaUploadSource _sourceFromString(String? source) {
    switch (source) {
      case 'cameraRoll':
        return MediaUploadSource.cameraRoll;
      case 'localFiles':
        return MediaUploadSource.localFiles;
      case 'googlePhotos':
        return MediaUploadSource.googlePhotos;
      default:
        return MediaUploadSource.localFiles;
    }
  }

  UploadedMediaFile _fileFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};

    return UploadedMediaFile(
      id: doc.id,
      fileName: (data['fileName'] as String?) ?? 'Uploaded image',
      source: _sourceFromString(data['source'] as String?),
      bytes: null,
      downloadUrl: (data['downloadUrl'] as String?) ?? (data['url'] as String?),
      originalPath: data['originalPath'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  MixAndMatchPairRecord _pairFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final imageName =
        (data['imageName'] as String?) ??
        (data['firstImageName'] as String?) ??
        'Image';
    final imageUrl =
        (data['imageUrl'] as String?) ??
        (data['downloadUrl'] as String?) ??
        (data['url'] as String?);

    return MixAndMatchPairRecord(
      id: doc.id,
      imageName: imageName,
      imageBytes: Uint8List(0),
      imageUrl: imageUrl,
      description: (data['description'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  String _contentTypeForFileName(String fileName, {required String fallback}) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return fallback;
    }
  }

  Future<void> refreshFromBackend() async {
    final collection = _mediaCollection();
    final pairCollection = _mixAndMatchCollection();
    if (collection == null || pairCollection == null) {
      return;
    }

    final mediaSnapshot = await collection
        .orderBy('createdAt', descending: false)
        .get();
    final pairSnapshot = await pairCollection
        .orderBy('createdAt', descending: false)
        .get();

    uploadedFiles.value = mediaSnapshot.docs.map(_fileFromDoc).toList();
    mixAndMatchPairs.value = pairSnapshot.docs.map(_pairFromDoc).toList();
  }

  Future<void> _writeFileToBackend(UploadedMediaFile file) async {
    final collection = _mediaCollection();
    final adminUid = _auth.currentUser?.uid;
    if (collection == null) {
      throw StateError('Admin user is not signed in.');
    }
    if (adminUid == null || adminUid.isEmpty) {
      throw StateError('Admin user is not signed in.');
    }

    String? downloadUrl = file.downloadUrl;
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      downloadUrl = await _storageService.uploadAdminBytes(
        adminUid: adminUid,
        folder: 'game_images',
        fileName: file.fileName,
        bytes: file.bytes!,
        contentType: _contentTypeForFileName(
          file.fileName,
          fallback: 'image/jpeg',
        ),
      );
    }

    await collection.doc(file.id).set({
      'fileName': file.fileName,
      'source': file.source.name,
      'downloadUrl': downloadUrl,
      'url': downloadUrl,
      'bytesBase64': FieldValue.delete(),
      'originalPath': file.originalPath,
      'createdAt': Timestamp.fromDate(file.createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _writeMixAndMatchPairToBackend(
    MixAndMatchPairRecord pair,
  ) async {
    final collection = _mixAndMatchCollection();
    final adminUid = _auth.currentUser?.uid;
    if (collection == null) {
      throw StateError('Admin user is not signed in.');
    }
    if (adminUid == null || adminUid.isEmpty) {
      throw StateError('Admin user is not signed in.');
    }

    String? imageUrl = pair.imageUrl;
    if (pair.imageBytes.isNotEmpty) {
      imageUrl = await _storageService.uploadAdminBytes(
        adminUid: adminUid,
        folder: 'mix_and_match',
        fileName: pair.imageName,
        bytes: pair.imageBytes,
        contentType: _contentTypeForFileName(
          pair.imageName,
          fallback: 'image/jpeg',
        ),
      );
    }

    await collection.doc(pair.id).set({
      'imageName': pair.imageName,
      'imageUrl': imageUrl,
      'downloadUrl': imageUrl,
      'url': imageUrl,
      'imageBytesBase64': FieldValue.delete(),
      // Keep legacy fields for backward compatibility with existing clients.
      'firstImageName': pair.imageName,
      'firstImageBytesBase64': FieldValue.delete(),
      'description': pair.description,
      'createdAt': Timestamp.fromDate(pair.createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> addUploadedFile(UploadedMediaFile file) async {
    final current = List<UploadedMediaFile>.from(uploadedFiles.value);
    current.add(file);
    uploadedFiles.value = current;

    try {
      await _writeFileToBackend(file);
    } catch (_) {
      uploadedFiles.value = uploadedFiles.value
          .where((item) => item.id != file.id)
          .toList();
      rethrow;
    }
  }

  Future<void> addGooglePhotosPlaceholder() async {
    final placeholder = UploadedMediaFile(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      fileName: 'Google Photos placeholder image',
      source: MediaUploadSource.googlePhotos,
      createdAt: DateTime.now(),
    );
    await addUploadedFile(placeholder);
  }

  Future<void> addMixAndMatchPair(MixAndMatchPairRecord pair) async {
    final current = List<MixAndMatchPairRecord>.from(mixAndMatchPairs.value);
    current.add(pair);
    mixAndMatchPairs.value = current;

    try {
      await _writeMixAndMatchPairToBackend(pair);
    } catch (_) {
      mixAndMatchPairs.value = mixAndMatchPairs.value
          .where((item) => item.id != pair.id)
          .toList();
      rethrow;
    }
  }

  Future<void> removeUploadedFile(String id) async {
    UploadedMediaFile? removed;
    for (final item in uploadedFiles.value) {
      if (item.id == id) {
        removed = item;
        break;
      }
    }
    uploadedFiles.value = uploadedFiles.value
        .where((item) => item.id != id)
        .toList();

    final collection = _mediaCollection();
    if (collection != null) {
      await collection.doc(id).delete();
    }
    await _storageService.deleteByDownloadUrl(removed?.downloadUrl);
  }

  Future<void> removeMixAndMatchPair(String id) async {
    MixAndMatchPairRecord? removed;
    for (final item in mixAndMatchPairs.value) {
      if (item.id == id) {
        removed = item;
        break;
      }
    }
    mixAndMatchPairs.value = mixAndMatchPairs.value
        .where((item) => item.id != id)
        .toList();

    final collection = _mixAndMatchCollection();
    if (collection != null) {
      await collection.doc(id).delete();
    }
    await _storageService.deleteByDownloadUrl(removed?.imageUrl);
  }

  Future<void> updateUploadedFile(UploadedMediaFile file) async {
    final current = List<UploadedMediaFile>.from(uploadedFiles.value);
    final index = current.indexWhere((item) => item.id == file.id);
    if (index >= 0) {
      current[index] = file;
    } else {
      current.add(file);
    }
    uploadedFiles.value = current;

    await _writeFileToBackend(file);
  }

  Future<int> sendToBackendPlaceholder() async {
    final collection = _mediaCollection();
    if (collection == null) {
      throw StateError('Admin user is not signed in.');
    }

    final files = uploadedFiles.value;
    for (final file in files) {
      await _writeFileToBackend(file);
    }

    return files.length;
  }

  /// Fetches puzzle/game images from the Firestore collection of the admin
  /// that is linked to the currently signed-in player. Falls back to the
  /// locally cached [uploadedFiles] when no player-link record is found
  /// (e.g. when the admin themselves is previewing the puzzle screen).
  Future<List<UploadedMediaFile>> fetchPuzzleImagesForLinkedAdmin() async {
    final user = _auth.currentUser;
    final email = user?.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) return [];

    // Look up the admin UID this player is linked to.
    try {
      final linkDoc = await _firestore
          .collection('player_links')
          .doc(email)
          .get();

      if (linkDoc.exists) {
        final adminUid = linkDoc.data()?['adminUid'] as String?;
        if (adminUid != null && adminUid.isNotEmpty) {
          final snapshot = await _firestore
              .collection('admins')
              .doc(adminUid)
              .collection('media_assets')
              .orderBy('createdAt', descending: false)
              .get();
          final images = snapshot.docs
              .map(_fileFromDoc)
              .where((f) => f.downloadUrl?.isNotEmpty ?? false)
              .toList();
          if (images.isNotEmpty) return images;
        }
      }
    } catch (_) {
      // Fall through to local cache.
    }

    // Fallback: use the admin's locally cached files (admin preview mode).
    return uploadedFiles.value
        .where((f) => f.downloadUrl?.isNotEmpty ?? false)
        .toList();
  }

  /// Fetches mix and match pairs from the Firestore collection of the admin
  /// linked to the currently signed-in player.
  Future<List<MixAndMatchPairRecord>>
  fetchMixAndMatchPairsForLinkedAdmin() async {
    final user = _auth.currentUser;
    final email = user?.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) return [];

    try {
      final linkDoc = await _firestore
          .collection('player_links')
          .doc(email)
          .get();

      if (linkDoc.exists) {
        final adminUid = linkDoc.data()?['adminUid'] as String?;
        if (adminUid != null && adminUid.isNotEmpty) {
          final snapshot = await _firestore
              .collection('admins')
              .doc(adminUid)
              .collection('mix_and_match_pairs')
              .orderBy('createdAt', descending: false)
              .get();
          final pairs = snapshot.docs.map(_pairFromDoc).toList();
          final usablePairs = pairs
              .where((pair) => pair.imageUrl?.isNotEmpty ?? false)
              .toList();
          if (usablePairs.isNotEmpty) return usablePairs;
        }
      }
    } catch (_) {
      // Fall through to local cache.
    }

    // Fallback: use locally cached admin pairs (admin preview mode).
    return mixAndMatchPairs.value;
  }
}
