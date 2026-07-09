import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

enum RewardType { photo, text, voice, video }

class RewardRecord {
  final String id;
  final RewardType type;
  final String? url;
  final String? text;
  final String fileName;
  final int unlockLevel;
  final bool unlocked;
  final DateTime createdAt;

  const RewardRecord({
    required this.id,
    required this.type,
    required this.fileName,
    required this.unlockLevel,
    required this.unlocked,
    required this.createdAt,
    this.url,
    this.text,
  });

  RewardRecord copyWith({
    String? id,
    RewardType? type,
    String? url,
    Object? text = _unset,
    String? fileName,
    int? unlockLevel,
    bool? unlocked,
    DateTime? createdAt,
  }) {
    return RewardRecord(
      id: id ?? this.id,
      type: type ?? this.type,
      url: url ?? this.url,
      text: identical(text, _unset) ? this.text : text as String?,
      fileName: fileName ?? this.fileName,
      unlockLevel: unlockLevel ?? this.unlockLevel,
      unlocked: unlocked ?? this.unlocked,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static RewardRecord fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final urlCandidates = <String?>[
      data['url'] as String?,
      data['imageUrl'] as String?,
      data['downloadUrl'] as String?,
      data['storageUrl'] as String?,
      data['mediaUrl'] as String?,
    ];

    final resolvedUrl = urlCandidates
        .whereType<String>()
        .map((value) => value.trim())
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');

    return RewardRecord(
      id: doc.id,
      type: rewardTypeFromString(data['type'] as String?),
      url: resolvedUrl.isEmpty ? null : resolvedUrl,
      text: data['text'] as String?,
      fileName: (data['fileName'] as String?) ?? 'Reward',
      unlockLevel: (data['unlockLevel'] as num?)?.toInt() ?? 1,
      unlocked: (data['unlocked'] as bool?) ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

RewardType rewardTypeFromString(String? value) {
  switch (value) {
    case 'photo':
      return RewardType.photo;
    case 'text':
      return RewardType.text;
    case 'voice':
      return RewardType.voice;
    case 'video':
      return RewardType.video;
    default:
      return RewardType.photo;
  }
}

String rewardTypeLabel(RewardType type) {
  switch (type) {
    case RewardType.photo:
      return 'Photo Memory';
    case RewardType.text:
      return 'Personalized Note';
    case RewardType.voice:
      return 'Voice Memo';
    case RewardType.video:
      return 'Video Message';
  }
}

bool rewardTypeSupportsUpload(RewardType type) {
  return type != RewardType.text;
}

bool rewardTypeAllowedAtLevel(RewardType type, int level) {
  if (level > 8) {
    return true;
  }

  switch (type) {
    case RewardType.photo:
      return level >= 1 && level <= 3;
    case RewardType.text:
      return level >= 4 && level <= 5;
    case RewardType.voice:
      return level >= 5 && level <= 6;
    case RewardType.video:
      return level >= 7 && level <= 8;
  }
}

String rewardUnlockHint(RewardType type) {
  switch (type) {
    case RewardType.photo:
      return 'Unlock at levels 1-3, or any level after 8.';
    case RewardType.text:
      return 'Unlock at levels 4-5, or any level after 8.';
    case RewardType.voice:
      return 'Unlock at levels 5-6, or any level after 8.';
    case RewardType.video:
      return 'Unlock at levels 7-8, or any level after 8.';
  }
}

class RewardUploadPayload {
  final RewardType type;
  final int unlockLevel;
  final String? fileName;
  final String? filePath;
  final Uint8List? bytes;
  final String? text;
  final String? contentType;

  const RewardUploadPayload({
    required this.type,
    required this.unlockLevel,
    this.fileName,
    this.filePath,
    this.bytes,
    this.text,
    this.contentType,
  });
}

class RewardService {
  RewardService._({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance;

  static final RewardService instance = RewardService._();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  final ValueNotifier<List<RewardRecord>> rewards =
      ValueNotifier<List<RewardRecord>>([]);

  CollectionReference<Map<String, dynamic>>? _rewardCollectionForAdmin(
    String? adminUid,
  ) {
    if (adminUid == null || adminUid.isEmpty) {
      return null;
    }

    return _firestore.collection('admins').doc(adminUid).collection('rewards');
  }

  CollectionReference<Map<String, dynamic>>? _currentAdminRewardCollection() {
    return _rewardCollectionForAdmin(_auth.currentUser?.uid);
  }

  Future<String?> _linkedAdminUidForCurrentUser() async {
    final email = _auth.currentUser?.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) {
      return null;
    }

    try {
      final directDoc = await _firestore
          .collection('player_links')
          .doc(email)
          .get();
      final adminUid = directDoc.data()?['adminUid'] as String?;
      if (adminUid != null && adminUid.isNotEmpty) {
        return adminUid;
      }
    } catch (_) {
      // Fall through to collection-group lookup.
    }

    try {
      final snapshot = await _firestore
          .collectionGroup('linked_player_feed')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final adminUid = snapshot.docs.first.data()['adminUid'] as String?;
      if (adminUid != null && adminUid.isNotEmpty) {
        return adminUid;
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<void> refreshForCurrentAdmin() async {
    final collection = _currentAdminRewardCollection();
    if (collection == null) {
      rewards.value = const <RewardRecord>[];
      return;
    }

    final snapshot = await collection
        .orderBy('createdAt', descending: false)
        .get();
    rewards.value = snapshot.docs.map(RewardRecord.fromDoc).toList();
  }

  String createRewardId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }

  UploadTask _uploadRewardAssetTask({
    required String rewardId,
    required RewardType type,
    required String fileName,
    required Uint8List bytes,
    String? filePath,
    String? contentType,
  }) {
    final adminUid = _auth.currentUser?.uid;
    if (adminUid == null || adminUid.isEmpty) {
      throw StateError('Admin user is not signed in.');
    }

    final sanitizedFileName = fileName.replaceAll(
      RegExp(r'[^A-Za-z0-9._-]'),
      '_',
    );
    final ref = _storage.ref().child(
      'admins/$adminUid/rewards/${type.name}/$rewardId-$sanitizedFileName',
    );
    final metadata = contentType == null
        ? null
        : SettableMetadata(contentType: contentType);

    // Upload every reward asset via putData and store only the download URL.
    return ref.putData(bytes, metadata);
  }

  Future<Uint8List> _resolveUploadBytes({
    Uint8List? bytes,
    String? filePath,
  }) async {
    if (bytes != null && bytes.isNotEmpty) {
      return bytes;
    }

    if (!kIsWeb && filePath != null && filePath.isNotEmpty) {
      return File(filePath).readAsBytes();
    }

    throw ArgumentError('Missing file data for upload.');
  }

  Stream<TaskSnapshot> _uploadRewardAsset({
    required String rewardId,
    required RewardType type,
    required String fileName,
    Uint8List? bytes,
    String? filePath,
    String? contentType,
  }) async* {
    final resolved = await _resolveUploadBytes(
      bytes: bytes,
      filePath: filePath,
    );
    final task = _uploadRewardAssetTask(
      rewardId: rewardId,
      type: type,
      fileName: fileName,
      bytes: resolved,
      filePath: filePath,
      contentType: contentType,
    );
    yield* task.snapshotEvents;
  }

  Stream<TaskSnapshot> uploadPhotoFile({
    required String rewardId,
    required String fileName,
    required Uint8List bytes,
    String? contentType,
  }) {
    return _uploadRewardAsset(
      rewardId: rewardId,
      type: RewardType.photo,
      fileName: fileName,
      bytes: bytes,
      filePath: null,
      contentType: contentType,
    );
  }

  Stream<TaskSnapshot> uploadVoiceFile({
    required String rewardId,
    required String fileName,
    required Uint8List bytes,
    String? contentType,
  }) {
    return _uploadRewardAsset(
      rewardId: rewardId,
      type: RewardType.voice,
      fileName: fileName,
      bytes: bytes,
      filePath: null,
      contentType: contentType,
    );
  }

  Stream<TaskSnapshot> uploadVideoFile({
    required String rewardId,
    required String fileName,
    required Uint8List bytes,
    String? contentType,
  }) {
    return _uploadRewardAsset(
      rewardId: rewardId,
      type: RewardType.video,
      fileName: fileName,
      bytes: bytes,
      filePath: null,
      contentType: contentType,
    );
  }

  Stream<TaskSnapshot> uploadRewardFile({
    required String rewardId,
    required RewardUploadPayload payload,
  }) {
    if (payload.type == RewardType.text) {
      throw ArgumentError('Text rewards do not upload files.');
    }
    final hasBytes = payload.bytes != null && payload.bytes!.isNotEmpty;
    final hasPath = payload.filePath != null && payload.filePath!.isNotEmpty;
    if (!hasBytes && !hasPath) {
      throw ArgumentError('Select a file before saving this reward.');
    }
    if (payload.fileName == null || payload.fileName!.isEmpty) {
      throw ArgumentError('Missing file name for upload.');
    }

    switch (payload.type) {
      case RewardType.photo:
        return _uploadRewardAsset(
          rewardId: rewardId,
          type: RewardType.photo,
          fileName: payload.fileName!,
          bytes: payload.bytes,
          filePath: payload.filePath,
          contentType: payload.contentType,
        );
      case RewardType.voice:
        return _uploadRewardAsset(
          rewardId: rewardId,
          type: RewardType.voice,
          fileName: payload.fileName!,
          bytes: payload.bytes,
          filePath: payload.filePath,
          contentType: payload.contentType,
        );
      case RewardType.video:
        return _uploadRewardAsset(
          rewardId: rewardId,
          type: RewardType.video,
          fileName: payload.fileName!,
          bytes: payload.bytes,
          filePath: payload.filePath,
          contentType: payload.contentType,
        );
      case RewardType.text:
        throw ArgumentError('Text rewards do not upload files.');
    }
  }

  UploadTask uploadRewardFileTask({
    required String rewardId,
    required RewardUploadPayload payload,
  }) {
    if (payload.type == RewardType.text) {
      throw ArgumentError('Text rewards do not upload files.');
    }
    final hasBytes = payload.bytes != null && payload.bytes!.isNotEmpty;
    final hasPath = payload.filePath != null && payload.filePath!.isNotEmpty;
    if (!hasBytes && !hasPath) {
      throw ArgumentError('Select a file before saving this reward.');
    }
    if (payload.fileName == null || payload.fileName!.isEmpty) {
      throw ArgumentError('Missing file name for upload.');
    }

    switch (payload.type) {
      case RewardType.photo:
        return _uploadRewardAssetTask(
          rewardId: rewardId,
          type: RewardType.photo,
          fileName: payload.fileName!,
          bytes: payload.bytes!,
          filePath: payload.filePath,
          contentType: payload.contentType,
        );
      case RewardType.voice:
        return _uploadRewardAssetTask(
          rewardId: rewardId,
          type: RewardType.voice,
          fileName: payload.fileName!,
          bytes: payload.bytes!,
          filePath: payload.filePath,
          contentType: payload.contentType,
        );
      case RewardType.video:
        return _uploadRewardAssetTask(
          rewardId: rewardId,
          type: RewardType.video,
          fileName: payload.fileName!,
          bytes: payload.bytes!,
          filePath: payload.filePath,
          contentType: payload.contentType,
        );
      case RewardType.text:
        throw ArgumentError('Text rewards do not upload files.');
    }
  }

  Future<RewardRecord> finalizeRewardUpload({
    required String rewardId,
    required RewardUploadPayload payload,
    TaskSnapshot? completedSnapshot,
  }) async {
    String? url;
    if (payload.type != RewardType.text) {
      final snapshot = completedSnapshot;
      if (snapshot == null) {
        throw StateError('Upload did not complete.');
      }
      url = await snapshot.ref.getDownloadURL();
    }

    final record = RewardRecord(
      id: rewardId,
      type: payload.type,
      url: url,
      text: payload.text?.trim(),
      fileName: payload.fileName ?? rewardTypeLabel(payload.type),
      unlockLevel: payload.unlockLevel,
      unlocked: false,
      createdAt: DateTime.now(),
    );

    final collection = _currentAdminRewardCollection();
    if (collection == null) {
      throw StateError('Admin user is not signed in.');
    }

    await collection.doc(record.id).set({
      'url': record.url,
      'text': record.text,
      'type': record.type.name,
      'fileName': record.fileName,
      'unlockLevel': record.unlockLevel,
      'unlocked': false,
      'createdAt': Timestamp.fromDate(record.createdAt),
    }, SetOptions(merge: true));

    rewards.value = <RewardRecord>[...rewards.value, record];
    return record;
  }

  Future<RewardRecord> addReward(RewardUploadPayload payload) async {
    if (!rewardTypeAllowedAtLevel(payload.type, payload.unlockLevel)) {
      throw ArgumentError(rewardUnlockHint(payload.type));
    }

    if (payload.type == RewardType.text) {
      final note = payload.text?.trim() ?? '';
      if (note.isEmpty) {
        throw ArgumentError('Add a note before saving this reward.');
      }
    } else if (((payload.bytes == null || payload.bytes!.isEmpty) &&
            (payload.filePath == null || payload.filePath!.isEmpty)) ||
        payload.fileName == null) {
      throw ArgumentError('Select a file before saving this reward.');
    }

    final rewardId = createRewardId();
    if (payload.type == RewardType.text) {
      return finalizeRewardUpload(rewardId: rewardId, payload: payload);
    }

    final resolvedBytes = await _resolveUploadBytes(
      bytes: payload.bytes,
      filePath: payload.filePath,
    );
    final snapshot = await uploadRewardFileTask(
      rewardId: rewardId,
      payload: RewardUploadPayload(
        type: payload.type,
        unlockLevel: payload.unlockLevel,
        fileName: payload.fileName,
        filePath: payload.filePath,
        bytes: resolvedBytes,
        text: payload.text,
        contentType: payload.contentType,
      ),
    );
    return finalizeRewardUpload(
      rewardId: rewardId,
      payload: payload,
      completedSnapshot: snapshot,
    );
  }

  Future<void> removeReward(RewardRecord record) async {
    rewards.value = rewards.value
        .where((item) => item.id != record.id)
        .toList();

    final collection = _currentAdminRewardCollection();
    if (collection != null) {
      await collection.doc(record.id).delete();
    }

    final adminUid = _auth.currentUser?.uid;
    if (adminUid != null && record.url != null && record.url!.isNotEmpty) {
      try {
        await _storage.refFromURL(record.url!).delete();
      } catch (_) {
        // Ignore storage cleanup failures if the file no longer exists.
      }
    }
  }

  Future<List<RewardRecord>> fetchRewardsForCurrentPlayer() async {
    final adminUid = await _linkedAdminUidForCurrentUser();
    if (adminUid == null || adminUid.isEmpty) {
      return const <RewardRecord>[];
    }

    final snapshot = await _rewardCollectionForAdmin(
      adminUid,
    )!.orderBy('createdAt', descending: false).get();
    return snapshot.docs.map(RewardRecord.fromDoc).toList();
  }

  Future<void> syncUnlockedRewardsForCurrentPlayer(
    int highestCompletedLevel,
  ) async {
    final adminUid = await _linkedAdminUidForCurrentUser();
    if (adminUid == null || adminUid.isEmpty) {
      return;
    }

    final snapshot = await _rewardCollectionForAdmin(adminUid)!
        .where('unlockLevel', isLessThanOrEqualTo: highestCompletedLevel)
        .where('unlocked', isEqualTo: false)
        .get();

    if (snapshot.docs.isEmpty) {
      return;
    }

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.set(doc.reference, {'unlocked': true}, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<int> unlockRewardsForCurrentPlayerLevel(int level) async {
    final adminUid = await _linkedAdminUidForCurrentUser();
    if (adminUid == null || adminUid.isEmpty) {
      return 0;
    }

    final snapshot = await _rewardCollectionForAdmin(adminUid)!
        .where('unlockLevel', isEqualTo: level)
        .where('unlocked', isEqualTo: false)
        .get();

    if (snapshot.docs.isEmpty) {
      return 0;
    }

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.set(doc.reference, {'unlocked': true}, SetOptions(merge: true));
    }
    await batch.commit();
    return snapshot.docs.length;
  }
}

class _UnsetValue {
  const _UnsetValue();
}

const _unset = _UnsetValue();
