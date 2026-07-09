import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:here_with_you/main.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';
import 'package:here_with_you/services/admin_media_service.dart';
import 'package:here_with_you/services/reward_service.dart';
import 'package:here_with_you/screens/manage_user_profile_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final AdminMediaService _mediaService = AdminMediaService.instance;
  final RewardService _rewardService = RewardService.instance;
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();

  bool _loading = true;
  bool _isUploadingPuzzleImage = false;
  bool _isUploadingMixAndMatch = false;
  final Map<RewardType, List<_PendingRewardUpload>> _pendingUploadsByType =
      <RewardType, List<_PendingRewardUpload>>{};
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    try {
      await _mediaService.refreshFromBackend();
      await _rewardService.refreshForCurrentAdmin();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _goToLoginScreen() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _pickFromCameraRoll() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final bytes = await image.readAsBytes();

    setState(() => _isUploadingPuzzleImage = true);
    try {
      final item = UploadedMediaFile(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        fileName: image.name,
        source: MediaUploadSource.cameraRoll,
        bytes: bytes,
        originalPath: kIsWeb ? null : image.path,
        createdAt: DateTime.now(),
      );
      await _mediaService.addUploadedFile(item);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image uploaded to Firestore from camera roll.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not upload image: $error')));
    } finally {
      if (mounted) {
        setState(() => _isUploadingPuzzleImage = false);
      }
    }
  }

  Future<void> _pickFromLocalFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final picked = result.files.first;
    if (picked.bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not read the selected image file.'),
        ),
      );
      return;
    }

    setState(() => _isUploadingPuzzleImage = true);
    try {
      final item = UploadedMediaFile(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        fileName: picked.name,
        source: MediaUploadSource.localFiles,
        bytes: picked.bytes,
        originalPath: kIsWeb ? null : picked.path,
        createdAt: DateTime.now(),
      );
      await _mediaService.addUploadedFile(item);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image uploaded to Firestore from local files.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not upload image: $error')));
    } finally {
      if (mounted) {
        setState(() => _isUploadingPuzzleImage = false);
      }
    }
  }

  Future<void> _showAddPuzzleImageSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFFFFF5E9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add puzzle image',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await _pickFromCameraRoll();
                },
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('Upload from camera roll'),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await _pickFromLocalFiles();
                },
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('Upload from local files'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<_PickedMixAndMatchImage?> _pickMixAndMatchImage(
    MediaUploadSource source,
  ) async {
    if (source == MediaUploadSource.cameraRoll) {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image == null) {
        return null;
      }

      final bytes = await image.readAsBytes();
      return _PickedMixAndMatchImage(fileName: image.name, bytes: bytes);
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final picked = result.files.first;
    if (picked.bytes == null) {
      return null;
    }

    return _PickedMixAndMatchImage(fileName: picked.name, bytes: picked.bytes!);
  }

  Future<void> _pickMixImageForField({
    required ValueSetter<_PickedMixAndMatchImage> onPicked,
  }) async {
    final source = await showModalBottomSheet<MediaUploadSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFFFFF5E9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Choose image source',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () =>
                    Navigator.pop(context, MediaUploadSource.cameraRoll),
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('Gallery photos'),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () =>
                    Navigator.pop(context, MediaUploadSource.localFiles),
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('Local files'),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) {
      return;
    }

    final image = await _pickMixAndMatchImage(source);
    if (image == null) {
      return;
    }

    onPicked(image);
  }

  Future<void> _showAddMixAndMatchSheet() async {
    final rootNavigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final TextEditingController descriptionController = TextEditingController();
    _PickedMixAndMatchImage? selectedImage;
    bool isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFFFF5E9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Add mix and match pair',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            await _pickMixImageForField(
                              onPicked: (image) {
                                setSheetState(() => selectedImage = image);
                              },
                            );
                          },
                    icon: const Icon(Icons.photo_outlined),
                    label: Text(
                      selectedImage == null
                          ? 'Select image'
                          : selectedImage!.fileName,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      alignLabelWithHint: true,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final description = descriptionController.text
                                .trim();
                            if (selectedImage == null || description.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please add an image and a description.',
                                  ),
                                ),
                              );
                              return;
                            }

                            setSheetState(() => isSubmitting = true);
                            setState(() => _isUploadingMixAndMatch = true);

                            try {
                              await _mediaService.addMixAndMatchPair(
                                MixAndMatchPairRecord(
                                  id: DateTime.now().microsecondsSinceEpoch
                                      .toString(),
                                  imageName: selectedImage!.fileName,
                                  imageBytes: selectedImage!.bytes,
                                  description: description,
                                  createdAt: DateTime.now(),
                                ),
                              );

                              if (!mounted) return;
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Mix and match pair uploaded to Firestore.',
                                  ),
                                ),
                              );
                              rootNavigator.pop();
                            } catch (error) {
                              setSheetState(() => isSubmitting = false);
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Could not upload mix and match pair: $error',
                                  ),
                                ),
                              );
                            } finally {
                              if (mounted) {
                                setState(() => _isUploadingMixAndMatch = false);
                              }
                            }
                          },
                    icon: isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_rounded),
                    label: Text(isSubmitting ? 'Uploading...' : 'Add pair'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    descriptionController.dispose();
  }

  Future<void> _replaceFromCameraRoll(
    String id,
    String fileName,
    DateTime createdAt,
  ) async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final bytes = await image.readAsBytes();
    await _mediaService.updateUploadedFile(
      UploadedMediaFile(
        id: id,
        fileName: image.name.isEmpty ? fileName : image.name,
        source: MediaUploadSource.cameraRoll,
        bytes: bytes,
        originalPath: kIsWeb ? null : image.path,
        createdAt: createdAt,
      ),
    );
  }

  Future<void> _replaceFromLocalFiles(
    String id,
    String fileName,
    DateTime createdAt,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final picked = result.files.first;
    await _mediaService.updateUploadedFile(
      UploadedMediaFile(
        id: id,
        fileName: picked.name.isEmpty ? fileName : picked.name,
        source: MediaUploadSource.localFiles,
        bytes: picked.bytes,
        originalPath: kIsWeb ? null : picked.path,
        createdAt: createdAt,
      ),
    );
  }

  Future<void> _replaceWithGooglePhotosPlaceholder(
    String id,
    String fileName,
    DateTime createdAt,
  ) async {
    await _mediaService.updateUploadedFile(
      UploadedMediaFile(
        id: id,
        fileName: fileName,
        source: MediaUploadSource.googlePhotos,
        createdAt: createdAt,
      ),
    );
  }

  Future<void> _showReplaceSheet(UploadedMediaFile file) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFFFFF5E9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Change image',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await _replaceFromCameraRoll(
                    file.id,
                    file.fileName,
                    file.createdAt,
                  );
                },
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('Replace from camera roll'),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await _replaceFromLocalFiles(
                    file.id,
                    file.fileName,
                    file.createdAt,
                  );
                },
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('Replace from local files'),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await _replaceWithGooglePhotosPlaceholder(
                    file.id,
                    file.fileName,
                    file.createdAt,
                  );
                },
                icon: const Icon(Icons.cloud_upload_rounded),
                label: const Text('Google Photos placeholder'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMediaPreview(UploadedMediaFile file) {
    final Uint8List? bytes = file.bytes;
    if (bytes != null && bytes.isNotEmpty) {
      return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
    }

    final url = file.downloadUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          color: const Color(0xFFFFE3DB),
          alignment: Alignment.center,
          child: const Icon(Icons.image_outlined, color: Color(0xFF5B3E00)),
        ),
      );
    }

    return Container(
      color: const Color(0xFFFFE3DB),
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: Color(0xFF5B3E00)),
    );
  }

  String _sourceLabel(MediaUploadSource source) {
    switch (source) {
      case MediaUploadSource.cameraRoll:
        return 'Camera Roll';
      case MediaUploadSource.localFiles:
        return 'Local Files';
      case MediaUploadSource.googlePhotos:
        return 'Google Photos';
    }
  }

  String _tabTitle() {
    switch (_selectedTabIndex) {
      case 0:
        return 'Images';
      case 1:
        return 'Rewards';
      case 2:
        return 'Manage Profile';
      default:
        return 'Admin Dashboard';
    }
  }

  Widget _buildEmptySectionCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7E4DC)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF6F6960),
        ),
      ),
    );
  }

  Widget _buildPuzzleAndMemoryList(List<UploadedMediaFile> files) {
    if (files.isEmpty) {
      return _buildEmptySectionCard(
        'No puzzle or memory match images added yet.',
      );
    }

    return Column(
      children: files
          .map(
            (file) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFFD7CC)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: _buildMediaPreview(file),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _sourceLabel(file.source),
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_rounded),
                    tooltip: 'Change image',
                    onPressed: () => _showReplaceSheet(file),
                  ),
                  IconButton(
                    onPressed: () => _mediaService.removeUploadedFile(file.id),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required VoidCallback onAdd,
    required bool isUploading,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF5B3E00),
            ),
          ),
        ),
        if (isUploading)
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.6),
          )
        else
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMixAndMatchList(List<MixAndMatchPairRecord> pairs) {
    if (pairs.isEmpty) {
      return _buildEmptySectionCard('No mix and match pairs added yet.');
    }

    return Column(
      children: pairs
          .map(
            (pair) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFFD7CC)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            height: 82,
                            child: pair.imageBytes.isNotEmpty
                                ? Image.memory(
                                    pair.imageBytes,
                                    fit: BoxFit.cover,
                                  )
                                : (pair.imageUrl != null &&
                                          pair.imageUrl!.isNotEmpty
                                      ? Image.network(
                                          pair.imageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => Container(
                                            color: const Color(0xFFFFE3DB),
                                            alignment: Alignment.center,
                                            child: const Icon(
                                              Icons.image_outlined,
                                            ),
                                          ),
                                        )
                                      : Container(
                                          color: const Color(0xFFFFE3DB),
                                          alignment: Alignment.center,
                                          child: const Icon(
                                            Icons.image_outlined,
                                          ),
                                        )),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.drag_indicator_rounded,
                        color: Color(0xFF6F6960),
                      ),
                      IconButton(
                        onPressed: () async {
                          await _mediaService.removeMixAndMatchPair(pair.id);
                        },
                        icon: const Icon(Icons.delete_outline_rounded),
                        tooltip: 'Remove pair',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    pair.description,
                    style: const TextStyle(
                      color: Color(0xFF4D4741),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildImagesTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ValueListenableBuilder<List<UploadedMediaFile>>(
        valueListenable: _mediaService.uploadedFiles,
        builder: (context, files, _) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              _buildSectionHeader(
                title: 'Puzzles and Memory Match',
                onAdd: _showAddPuzzleImageSheet,
                isUploading: _isUploadingPuzzleImage,
              ),
              const SizedBox(height: 10),
              _buildPuzzleAndMemoryList(files),
              const SizedBox(height: 18),
              _buildSectionHeader(
                title: 'Mix and Match',
                onAdd: _showAddMixAndMatchSheet,
                isUploading: _isUploadingMixAndMatch,
              ),
              const SizedBox(height: 10),
              ValueListenableBuilder<List<MixAndMatchPairRecord>>(
                valueListenable: _mediaService.mixAndMatchPairs,
                builder: (context, pairs, _) {
                  return _buildMixAndMatchList(pairs);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRewardsTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ValueListenableBuilder<List<RewardRecord>>(
        valueListenable: _rewardService.rewards,
        builder: (context, rewards, _) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              _buildRewardSection(
                type: RewardType.photo,
                rewards: rewards
                    .where((reward) => reward.type == RewardType.photo)
                    .toList(),
              ),
              const SizedBox(height: 18),
              _buildRewardSection(
                type: RewardType.text,
                rewards: rewards
                    .where((reward) => reward.type == RewardType.text)
                    .toList(),
              ),
              const SizedBox(height: 18),
              _buildRewardSection(
                type: RewardType.voice,
                rewards: rewards
                    .where((reward) => reward.type == RewardType.voice)
                    .toList(),
              ),
              const SizedBox(height: 18),
              _buildRewardSection(
                type: RewardType.video,
                rewards: rewards
                    .where((reward) => reward.type == RewardType.video)
                    .toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  List<_PendingRewardUpload> _pendingForType(RewardType type) {
    return _pendingUploadsByType[type] ?? const <_PendingRewardUpload>[];
  }

  void _addPendingUpload(_PendingRewardUpload upload) {
    final items = List<_PendingRewardUpload>.from(_pendingForType(upload.type));
    items.add(upload);
    setState(() {
      _pendingUploadsByType[upload.type] = items;
    });
  }

  void _updatePendingUpload(
    String uploadId, {
    double? progress,
    String? errorMessage,
  }) {
    setState(() {
      for (final entry in _pendingUploadsByType.entries) {
        final index = entry.value.indexWhere((item) => item.id == uploadId);
        if (index < 0) {
          continue;
        }

        entry.value[index] = entry.value[index].copyWith(
          progress: progress,
          errorMessage: errorMessage,
          overwriteErrorMessage: true,
        );
        return;
      }
    });
  }

  void _removePendingUpload(String uploadId) {
    setState(() {
      for (final type in _pendingUploadsByType.keys.toList()) {
        final current = _pendingUploadsByType[type]!;
        final updated = current.where((item) => item.id != uploadId).toList();
        if (updated.isEmpty) {
          _pendingUploadsByType.remove(type);
        } else {
          _pendingUploadsByType[type] = updated;
        }
      }
    });
  }

  Future<void> _startRewardUpload(_PendingRewardUpload pending) async {
    StreamSubscription<TaskSnapshot>? progressSubscription;
    UploadTask? uploadTask;
    try {
      uploadTask = _rewardService.uploadRewardFileTask(
        rewardId: pending.rewardId,
        payload: pending.payload,
      );

      progressSubscription = uploadTask.snapshotEvents.listen((snapshot) {
        final total = snapshot.totalBytes;
        final progress = total <= 0 ? 0.0 : snapshot.bytesTransferred / total;
        if (!mounted) {
          return;
        }
        _updatePendingUpload(
          pending.id,
          progress: progress,
          errorMessage: null,
        );
      });

      final completedSnapshot = await uploadTask.timeout(
        const Duration(minutes: 5),
      );

      if (!mounted) {
        return;
      }
      _updatePendingUpload(pending.id, progress: 1, errorMessage: null);

      await _rewardService.finalizeRewardUpload(
        rewardId: pending.rewardId,
        payload: pending.payload,
        completedSnapshot: completedSnapshot,
      );

      if (!mounted) {
        return;
      }

      _removePendingUpload(pending.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${rewardTypeLabel(pending.type)} added.')),
      );
    } on TimeoutException {
      if (uploadTask != null) {
        await uploadTask.cancel();
      }
      if (!mounted) {
        return;
      }
      _updatePendingUpload(
        pending.id,
        errorMessage: 'Upload took too long. Please retry.',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload took too long. Please try again.'),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }
      _updatePendingUpload(
        pending.id,
        errorMessage: 'Upload failed. Please retry.',
      );

      final errorMessage = switch (error.code) {
        'unauthorized' => 'Upload blocked by Firebase Storage rules.',
        'canceled' => 'Upload was canceled.',
        'network-request-failed' =>
          'Network error while uploading. Please try again.',
        _ => 'Could not upload reward: ${error.message ?? error.code}',
      };

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      _updatePendingUpload(
        pending.id,
        errorMessage: 'Upload failed. Please retry.',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not upload reward: $error')),
      );
    } finally {
      await progressSubscription?.cancel();
    }
  }

  Future<void> _retryPendingUpload(_PendingRewardUpload upload) async {
    _updatePendingUpload(upload.id, progress: 0, errorMessage: null);
    await _startRewardUpload(upload);
  }

  Future<void> _openRewardDetails(RewardRecord reward) async {
    switch (reward.type) {
      case RewardType.photo:
        await _showPhotoPreview(reward);
        break;
      case RewardType.video:
        await _openVideoFullscreen(reward);
        break;
      case RewardType.voice:
        break;
      case RewardType.text:
        await _showNoteBottomSheet(reward);
        break;
    }
  }

  Future<void> _showPhotoPreview(RewardRecord reward) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFFFFF5E9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: reward.url == null || reward.url!.isEmpty
                        ? const ColoredBox(color: Color(0xFFFFE3DB))
                        : Image.network(reward.url!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openVideoFullscreen(RewardRecord reward) async {
    final url = reward.url;
    if (url == null || url.isEmpty) {
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullscreenRewardVideoPlayer(url: url),
      ),
    );
  }

  Future<void> _showNoteBottomSheet(RewardRecord reward) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFFFFF5E9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Personalized Note',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF5B3E00),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                reward.text?.trim().isNotEmpty == true
                    ? reward.text!.trim()
                    : 'No note saved yet.',
                style: const TextStyle(
                  color: Color(0xFF5B3E00),
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRewardSection({
    required RewardType type,
    required List<RewardRecord> rewards,
  }) {
    final pendingUploads = _pendingForType(type);
    final isUploading = pendingUploads.any(
      (upload) => upload.errorMessage == null && upload.progress < 1,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: rewardTypeLabel(type),
          onAdd: () => _showAddRewardSheet(type),
          isUploading: isUploading,
        ),
        const SizedBox(height: 8),
        Text(
          rewardUnlockHint(type),
          style: const TextStyle(color: Color(0xFF6F6960), height: 1.35),
        ),
        const SizedBox(height: 10),
        if (rewards.isEmpty && pendingUploads.isEmpty)
          _buildEmptySectionCard(
            'No ${rewardTypeLabel(type).toLowerCase()} items added yet.',
          )
        else
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: pendingUploads.length + rewards.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                if (index < pendingUploads.length) {
                  final pending = pendingUploads[index];
                  return _UploadingRewardCard(
                    upload: pending,
                    onRetry: () => _retryPendingUpload(pending),
                  );
                }

                final reward = rewards[index - pendingUploads.length];
                return _AdminRewardPreviewCard(
                  reward: reward,
                  onDelete: () => _rewardService.removeReward(reward),
                  onTap: () => _openRewardDetails(reward),
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _showAddRewardSheet(RewardType type) async {
    final rootNavigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final TextEditingController noteController = TextEditingController();
    _PickedRewardAsset? selectedAsset;
    int unlockLevel = _defaultUnlockLevelForType(type);
    bool isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFFFF5E9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final levelAllowed = rewardTypeAllowedAtLevel(type, unlockLevel);

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Add ${rewardTypeLabel(type)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    rewardUnlockHint(type),
                    style: const TextStyle(
                      color: Color(0xFF6F6960),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: levelAllowed
                            ? const Color(0xFFE7E4DC)
                            : const Color(0xFFFFA9A3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Unlock level',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF5B3E00),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Level $unlockLevel',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFFF6B6B),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: isSubmitting || unlockLevel <= 1
                              ? null
                              : () => setSheetState(() => unlockLevel -= 1),
                          icon: const Icon(Icons.remove_circle_outline_rounded),
                        ),
                        IconButton(
                          onPressed: isSubmitting
                              ? null
                              : () => setSheetState(() => unlockLevel += 1),
                          icon: const Icon(Icons.add_circle_outline_rounded),
                        ),
                      ],
                    ),
                  ),
                  if (!levelAllowed) ...[
                    const SizedBox(height: 8),
                    Text(
                      'This reward type cannot unlock at level $unlockLevel.',
                      style: const TextStyle(
                        color: Color(0xFFB3261E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (type == RewardType.text)
                    TextField(
                      controller: noteController,
                      maxLines: 4,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Personalized note',
                        alignLabelWithHint: true,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    )
                  else if (type == RewardType.voice)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton.icon(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final asset = await _pickExistingVoiceMemo();
                                  if (asset == null) {
                                    return;
                                  }

                                  setSheetState(() => selectedAsset = asset);
                                },
                          icon: const Icon(Icons.audio_file_rounded),
                          label: Text(
                            selectedAsset == null
                                ? 'Upload existing recording'
                                : selectedAsset!.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final asset = await _recordVoiceMemoInApp();
                                  if (asset == null) {
                                    return;
                                  }

                                  setSheetState(() => selectedAsset = asset);
                                },
                          icon: const Icon(Icons.mic_rounded),
                          label: const Text('Record voice memo in app'),
                        ),
                      ],
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final asset = await _pickRewardAsset(type);
                              if (asset == null) {
                                return;
                              }

                              setSheetState(() => selectedAsset = asset);
                            },
                      icon: Icon(_rewardPickerIcon(type)),
                      label: Text(
                        selectedAsset == null
                            ? _rewardPickerLabel(type)
                            : selectedAsset!.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            if (!rewardTypeAllowedAtLevel(type, unlockLevel)) {
                              messenger.showSnackBar(
                                SnackBar(content: Text(rewardUnlockHint(type))),
                              );
                              return;
                            }

                            if (type == RewardType.text &&
                                noteController.text.trim().isEmpty) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please add a note before saving.',
                                  ),
                                ),
                              );
                              return;
                            }

                            if (type != RewardType.text &&
                                selectedAsset == null) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please select a file before saving.',
                                  ),
                                ),
                              );
                              return;
                            }

                            setSheetState(() => isSubmitting = true);

                            try {
                              final payload = RewardUploadPayload(
                                type: type,
                                unlockLevel: unlockLevel,
                                fileName: selectedAsset?.fileName,
                                filePath: selectedAsset?.filePath,
                                bytes: selectedAsset?.bytes,
                                text: type == RewardType.text
                                    ? noteController.text
                                    : null,
                                contentType: selectedAsset?.contentType,
                              );

                              if (type == RewardType.text) {
                                await _rewardService.addReward(payload);
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${rewardTypeLabel(type)} added.',
                                    ),
                                  ),
                                );
                              } else {
                                final pending = _PendingRewardUpload(
                                  id: DateTime.now().microsecondsSinceEpoch
                                      .toString(),
                                  rewardId: _rewardService.createRewardId(),
                                  type: type,
                                  unlockLevel: unlockLevel,
                                  fileName: selectedAsset!.fileName,
                                  payload: payload,
                                  progress: 0,
                                );
                                _addPendingUpload(pending);
                                unawaited(_startRewardUpload(pending));
                              }

                              if (!mounted) return;
                              rootNavigator.pop();
                            } catch (error) {
                              setSheetState(() => isSubmitting = false);
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Could not add reward: $error'),
                                ),
                              );
                            }
                          },
                    icon: isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_rounded),
                    label: Text(isSubmitting ? 'Saving...' : 'Add'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    noteController.dispose();
  }

  int _defaultUnlockLevelForType(RewardType type) {
    switch (type) {
      case RewardType.photo:
        return 1;
      case RewardType.text:
        return 4;
      case RewardType.voice:
        return 5;
      case RewardType.video:
        return 7;
    }
  }

  IconData _rewardPickerIcon(RewardType type) {
    switch (type) {
      case RewardType.photo:
        return Icons.photo_library_rounded;
      case RewardType.text:
        return Icons.note_alt_rounded;
      case RewardType.voice:
        return Icons.mic_rounded;
      case RewardType.video:
        return Icons.videocam_rounded;
    }
  }

  String _rewardPickerLabel(RewardType type) {
    switch (type) {
      case RewardType.photo:
        return 'Choose photo from gallery';
      case RewardType.text:
        return 'Add note';
      case RewardType.voice:
        return 'Choose voice memo';
      case RewardType.video:
        return 'Choose video from gallery';
    }
  }

  Future<_PickedRewardAsset?> _pickExistingVoiceMemo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['m4a', 'mp3', 'wav', 'aac'],
      withData: true,
      withReadStream: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }

    final picked = result.files.first;
    if (picked.path == null &&
        picked.bytes == null &&
        picked.readStream == null) {
      return null;
    }

    final normalizedFileName = _normalizedRewardFileName(
      picked.name.isEmpty
          ? 'voice_memo_${DateTime.now().millisecondsSinceEpoch}.m4a'
          : picked.name,
      type: RewardType.voice,
    );

    Uint8List? bytes = picked.bytes;
    if ((bytes == null || bytes.isEmpty) && picked.readStream != null) {
      bytes = await _readBytesFromStream(picked.readStream!);
    }
    if (bytes == null && picked.path != null && picked.path!.isNotEmpty) {
      bytes = await XFile(picked.path!).readAsBytes();
    }
    if (bytes == null || bytes.isEmpty) {
      return null;
    }

    final filePath =
        picked.path ??
        (kIsWeb
            ? normalizedFileName
            : await _persistBytesToTempFile(bytes, normalizedFileName));

    return _PickedRewardAsset(
      fileName: normalizedFileName,
      filePath: filePath,
      bytes: bytes,
      contentType: _contentTypeForFileName(
        normalizedFileName,
        fallback: 'audio/m4a',
      ),
    );
  }

  Future<Uint8List> _readBytesFromStream(Stream<List<int>> stream) async {
    final chunks = <int>[];
    await for (final chunk in stream) {
      chunks.addAll(chunk);
    }
    return Uint8List.fromList(chunks);
  }

  Future<_PickedRewardAsset?> _recordVoiceMemoInApp() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!mounted) {
      return null;
    }
    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone permission is required to record audio.'),
        ),
      );
      return null;
    }

    bool isSheetVisible = true;
    Timer? recordingTicker;
    Duration recordingDuration = Duration.zero;

    final result = await showModalBottomSheet<_PickedRewardAsset>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFFFFF5E9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        bool isRecording = false;
        bool isSaving = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> startRecording() async {
              final fileName =
                  'voice_memo_${DateTime.now().millisecondsSinceEpoch}.m4a';
              final path = kIsWeb
                  ? fileName
                  : '${(await getTemporaryDirectory()).path}/$fileName';

              await _audioRecorder.start(
                const RecordConfig(encoder: AudioEncoder.aacLc),
                path: path,
              );
              recordingTicker?.cancel();
              setSheetState(() {
                isRecording = true;
                recordingDuration = Duration.zero;
              });

              recordingTicker = Timer.periodic(const Duration(seconds: 1), (_) {
                if (!isSheetVisible) {
                  return;
                }

                setSheetState(() {
                  recordingDuration += const Duration(seconds: 1);
                });
              });
            }

            Future<void> stopAndSave() async {
              setSheetState(() => isSaving = true);
              recordingTicker?.cancel();
              final path = await _audioRecorder.stop();
              if (path == null || path.isEmpty) {
                setSheetState(() {
                  isRecording = false;
                  isSaving = false;
                });
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Unable to save the voice recording.'),
                  ),
                );
                return;
              }

              final bytes = await XFile(path).readAsBytes();
              if (!context.mounted) {
                return;
              }

              Navigator.pop(
                context,
                _PickedRewardAsset(
                  fileName:
                      'voice_memo_${DateTime.now().millisecondsSinceEpoch}.m4a',
                  filePath: path,
                  bytes: bytes,
                  contentType: 'audio/m4a',
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Record voice memo',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap start to record, then stop to save this memo.',
                    style: TextStyle(color: Color(0xFF6F6960), height: 1.35),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Recording time: ${_formatDuration(recordingDuration)}',
                    style: TextStyle(
                      color: isRecording
                          ? const Color(0xFFB3261E)
                          : const Color(0xFF6F6960),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: isSaving || isRecording
                        ? null
                        : () async {
                            try {
                              await startRecording();
                            } catch (error) {
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Could not start recording: $error',
                                  ),
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.fiber_manual_record_rounded),
                    label: const Text('Start recording'),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: isSaving || !isRecording
                        ? null
                        : () async {
                            try {
                              await stopAndSave();
                            } catch (error) {
                              setSheetState(() {
                                isRecording = false;
                                isSaving = false;
                              });
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Could not save audio: $error'),
                                ),
                              );
                            }
                          },
                    icon: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.stop_circle_outlined),
                    label: Text(
                      isSaving ? 'Saving...' : 'Stop and use recording',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            recordingTicker?.cancel();
                            if (isRecording) {
                              await _audioRecorder.stop();
                            }
                            if (!context.mounted) {
                              return;
                            }
                            Navigator.pop(context);
                          },
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    isSheetVisible = false;
    recordingTicker?.cancel();

    final isStillRecording = await _audioRecorder.isRecording();
    if (isStillRecording) {
      await _audioRecorder.stop();
    }

    return result;
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<_PickedRewardAsset?> _pickRewardAsset(RewardType type) async {
    switch (type) {
      case RewardType.photo:
        final image = await _imagePicker.pickImage(source: ImageSource.gallery);
        if (image == null) {
          return null;
        }
        final originalName = image.name.trim().isEmpty
            ? 'photo_memory.heic'
            : image.name;
        final sourceExtension = originalName.contains('.')
            ? originalName.split('.').last.toLowerCase()
            : '';

        Uint8List bytes = await image.readAsBytes();
        var normalizedFileName = _normalizedRewardFileName(
          originalName,
          type: RewardType.photo,
        );

        if (sourceExtension == 'heic' || sourceExtension == 'heif') {
          try {
            final converted = await FlutterImageCompress.compressWithList(
              bytes,
              format: CompressFormat.jpeg,
              quality: 94,
            );
            if (converted.isNotEmpty) {
              bytes = Uint8List.fromList(converted);
              normalizedFileName = _replaceExtension(
                normalizedFileName,
                'jpg',
              );
            }
          } catch (_) {
            // Keep original bytes and extension if conversion is unavailable.
          }
        }

        return _PickedRewardAsset(
          fileName: normalizedFileName,
          filePath: image.path,
          bytes: bytes,
          contentType: _contentTypeForFileName(
            normalizedFileName,
            fallback: 'image/jpeg',
          ),
        );
      case RewardType.video:
        final video = await _imagePicker.pickVideo(source: ImageSource.gallery);
        if (video == null) {
          return null;
        }
        final normalizedFileName = _normalizedRewardFileName(
          video.name,
          type: RewardType.video,
        );
        return _PickedRewardAsset(
          fileName: normalizedFileName,
          filePath: video.path,
          bytes: await video.readAsBytes(),
          contentType: _contentTypeForFileName(
            normalizedFileName,
            fallback: 'video/mp4',
          ),
        );
      case RewardType.voice:
        return _pickExistingVoiceMemo();
      case RewardType.text:
        return null;
    }
  }

  Future<String> _persistBytesToTempFile(
    Uint8List bytes,
    String fileName,
  ) async {
    final directory = await getTemporaryDirectory();
    final sanitized = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path =
        '${directory.path}/${DateTime.now().microsecondsSinceEpoch}_$sanitized';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
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
      case 'heic':
      case 'heif':
        return 'image/heic';
      case 'mp4':
        return 'video/mp4';
      case 'm4v':
        return 'video/x-m4v';
      case 'mov':
        return 'video/quicktime';
      case 'm4a':
        return 'audio/m4a';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'aac':
        return 'audio/aac';
      default:
        return fallback;
    }
  }

  String _normalizedRewardFileName(
    String originalName, {
    required RewardType type,
  }) {
    final trimmed = originalName.trim();
    final fallbackBase = switch (type) {
      RewardType.photo => 'photo_memory',
      RewardType.video => 'video_message',
      RewardType.voice => 'voice_memo',
      RewardType.text => 'reward_note',
    };

    final hasDot = trimmed.contains('.');
    final rawBase = hasDot
        ? trimmed.substring(0, trimmed.lastIndexOf('.'))
        : (trimmed.isEmpty ? fallbackBase : trimmed);
    final rawExt = hasDot
        ? trimmed.substring(trimmed.lastIndexOf('.') + 1)
        : '';

    final base = rawBase
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^[_\.]+|[_\.]+$'), '');

    final normalizedExt = _normalizedRewardExtension(
      extension: rawExt.toLowerCase(),
      type: type,
    );
    final safeBase = base.isEmpty ? fallbackBase : base;
    return '$safeBase.$normalizedExt';
  }

  String _normalizedRewardExtension({
    required String extension,
    required RewardType type,
  }) {
    switch (type) {
      case RewardType.photo:
        if (extension == 'jpg' ||
            extension == 'jpeg' ||
            extension == 'png' ||
            extension == 'heic' ||
            extension == 'heif') {
          return extension == 'jpeg' ? 'jpg' : extension;
        }
        return 'jpg';
      case RewardType.video:
        if (extension == 'mov' || extension == 'm4v') {
          // Rename to mp4 for rules that allow mp4 uploads only.
          return 'mp4';
        }
        if (extension == 'mp4') {
          return 'mp4';
        }
        return 'mp4';
      case RewardType.voice:
        if (extension == 'm4a' ||
            extension == 'mp3' ||
            extension == 'wav' ||
            extension == 'aac') {
          return extension;
        }
        return 'm4a';
      case RewardType.text:
        return 'txt';
    }
  }

  String _replaceExtension(String fileName, String newExtension) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex < 0) {
      return '$fileName.$newExtension';
    }
    return '${fileName.substring(0, dotIndex)}.$newExtension';
  }

  @override
  Widget build(BuildContext context) {
    late final Widget body;
    switch (_selectedTabIndex) {
      case 0:
        body = _buildImagesTab();
        break;
      case 1:
        body = _buildRewardsTab();
        break;
      case 2:
        body = const ManageUserProfileTabContent();
        break;
      default:
        body = _buildImagesTab();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_tabTitle()),
        backgroundColor: const Color(0xFFFF6B6B),
        foregroundColor: const Color(0xFF5B3E00),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back to login',
          onPressed: _goToLoginScreen,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
            onPressed: _goToLoginScreen,
          ),
        ],
      ),
      backgroundColor: const Color(0xFFEFEEE9),
      body: body,
      bottomNavigationBar: NavigationBar(
        height: 72,
        backgroundColor: const Color(0xFFFFF0E6),
        indicatorColor: const Color(0xFFFFD7CC),
        selectedIndex: _selectedTabIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedTabIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.photo_library_rounded),
            label: 'Images',
          ),
          NavigationDestination(
            icon: Icon(Icons.card_giftcard_rounded),
            label: 'Rewards',
          ),
          NavigationDestination(
            icon: Icon(Icons.manage_accounts_rounded),
            label: 'Manage Profile',
          ),
        ],
      ),
    );
  }
}

class _PickedMixAndMatchImage {
  final String fileName;
  final Uint8List bytes;

  const _PickedMixAndMatchImage({required this.fileName, required this.bytes});
}

class _PickedRewardAsset {
  final String fileName;
  final String filePath;
  final Uint8List? bytes;
  final String contentType;

  const _PickedRewardAsset({
    required this.fileName,
    required this.filePath,
    this.bytes,
    required this.contentType,
  });
}

class _PendingRewardUpload {
  final String id;
  final String rewardId;
  final RewardType type;
  final int unlockLevel;
  final String fileName;
  final RewardUploadPayload payload;
  final double progress;
  final String? errorMessage;

  const _PendingRewardUpload({
    required this.id,
    required this.rewardId,
    required this.type,
    required this.unlockLevel,
    required this.fileName,
    required this.payload,
    required this.progress,
    this.errorMessage,
  });

  _PendingRewardUpload copyWith({
    double? progress,
    String? errorMessage,
    bool overwriteErrorMessage = false,
  }) {
    return _PendingRewardUpload(
      id: id,
      rewardId: rewardId,
      type: type,
      unlockLevel: unlockLevel,
      fileName: fileName,
      payload: payload,
      progress: progress ?? this.progress,
      errorMessage: overwriteErrorMessage ? errorMessage : this.errorMessage,
    );
  }
}

class _UploadingRewardCard extends StatelessWidget {
  const _UploadingRewardCard({required this.upload, required this.onRetry});

  final _PendingRewardUpload upload;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final hasError = upload.errorMessage != null;

    return Container(
      width: 160,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasError ? const Color(0xFFFFA9A3) : const Color(0xFFFFD7CC),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0E6),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    hasError
                        ? Icons.error_outline_rounded
                        : Icons.cloud_upload_rounded,
                    size: 34,
                    color: hasError
                        ? const Color(0xFFB3261E)
                        : const Color(0xFFFF6B6B),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasError ? 'Upload failed' : 'Uploading...',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF5B3E00),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (hasError)
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        minimumSize: const Size(0, 30),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                      ),
                      onPressed: onRetry,
                      child: const Text('Retry'),
                    )
                  else
                    LinearProgressIndicator(
                      value: upload.progress.clamp(0.0, 1.0),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(8),
                      backgroundColor: const Color(0xFFFFD7CC),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFFF6B6B),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Level ${upload.unlockLevel}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF5B3E00),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            upload.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF6F6960)),
          ),
        ],
      ),
    );
  }
}

class _AdminRewardPreviewCard extends StatefulWidget {
  const _AdminRewardPreviewCard({
    required this.reward,
    required this.onDelete,
    required this.onTap,
  });

  final RewardRecord reward;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  @override
  State<_AdminRewardPreviewCard> createState() =>
      _AdminRewardPreviewCardState();
}

class _AdminRewardPreviewCardState extends State<_AdminRewardPreviewCard> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<PlayerState>? _playerStateSub;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;

  RewardRecord get _reward => widget.reward;

  @override
  void initState() {
    super.initState();
    if (_reward.type == RewardType.voice) {
      _positionSub = _audioPlayer.onPositionChanged.listen((position) {
        if (mounted) {
          setState(() => _position = position);
        }
      });
      _durationSub = _audioPlayer.onDurationChanged.listen((duration) {
        if (mounted) {
          setState(() => _duration = duration);
        }
      });
      _playerStateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
        if (mounted) {
          setState(() => _isPlaying = state == PlayerState.playing);
        }
      });
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playerStateSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _toggleVoicePlayback() async {
    final url = _reward.url;
    if (url == null || url.isEmpty) {
      return;
    }

    if (_isPlaying) {
      await _audioPlayer.pause();
      return;
    }

    if (_position > Duration.zero && _position < _duration) {
      await _audioPlayer.resume();
      return;
    }

    await _audioPlayer.play(UrlSource(url));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _reward.type == RewardType.voice
            ? _toggleVoicePlayback
            : widget.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFFD7CC)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _AdminRewardPreviewBody(
                    reward: _reward,
                    isVoicePlaying: _isPlaying,
                    voiceProgress: _duration.inMilliseconds == 0
                        ? 0
                        : _position.inMilliseconds / _duration.inMilliseconds,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Level ${_reward.unlockLevel}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF5B3E00),
                      ),
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    tooltip: 'Delete reward',
                  ),
                ],
              ),
              Text(
                _reward.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF6F6960)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminRewardPreviewBody extends StatelessWidget {
  const _AdminRewardPreviewBody({
    required this.reward,
    this.isVoicePlaying = false,
    this.voiceProgress = 0,
  });

  final RewardRecord reward;
  final bool isVoicePlaying;
  final double voiceProgress;

  @override
  Widget build(BuildContext context) {
    switch (reward.type) {
      case RewardType.photo:
        if (reward.url == null || reward.url!.isEmpty) {
          return _RewardPlaceholder(icon: Icons.photo_rounded, label: 'Photo');
        }

        return Image.network(
          reward.url!,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const _RewardPlaceholder(
            icon: Icons.broken_image_outlined,
            label: 'Photo',
          ),
        );
      case RewardType.video:
        final url = reward.url;
        if (url == null || url.isEmpty) {
          return const _RewardPlaceholder(
            icon: Icons.play_circle_fill_rounded,
            label: 'Video',
          );
        }

        return _VideoThumbnailPreview(url: url);
      case RewardType.voice:
        return Container(
          color: const Color(0xFFFFF0E6),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isVoicePlaying
                    ? Icons.pause_circle_filled_rounded
                    : Icons.mic_rounded,
                size: 38,
                color: const Color(0xFFFF6B6B),
              ),
              const SizedBox(height: 8),
              Text(
                isVoicePlaying ? 'Tap to pause' : 'Tap to play',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF5B3E00),
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: voiceProgress.clamp(0.0, 1.0),
                minHeight: 6,
                borderRadius: BorderRadius.circular(8),
                backgroundColor: const Color(0xFFFFD7CC),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFFFF6B6B),
                ),
              ),
            ],
          ),
        );
      case RewardType.text:
        return Container(
          color: const Color(0xFFFFF6ED),
          padding: const EdgeInsets.all(12),
          child: Text(
            reward.text ?? '',
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF5B3E00),
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
    }
  }
}

class _VideoThumbnailPreview extends StatefulWidget {
  const _VideoThumbnailPreview({required this.url});

  final String url;

  @override
  State<_VideoThumbnailPreview> createState() => _VideoThumbnailPreviewState();
}

class _VideoThumbnailPreviewState extends State<_VideoThumbnailPreview> {
  VideoPlayerController? _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _loading = false;
      });
    } catch (_) {
      await controller.dispose();
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_loading) {
      return const ColoredBox(
        color: Color(0xFFFFE3DB),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (controller == null) {
      return const _RewardPlaceholder(
        icon: Icons.play_circle_fill_rounded,
        label: 'Video',
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
        Container(color: Colors.black.withValues(alpha: 0.2)),
        const Center(
          child: Icon(
            Icons.play_circle_fill_rounded,
            color: Colors.white,
            size: 42,
          ),
        ),
      ],
    );
  }
}

class _FullscreenRewardVideoPlayer extends StatefulWidget {
  const _FullscreenRewardVideoPlayer({required this.url});

  final String url;

  @override
  State<_FullscreenRewardVideoPlayer> createState() =>
      _FullscreenRewardVideoPlayerState();
}

class _FullscreenRewardVideoPlayerState
    extends State<_FullscreenRewardVideoPlayer> {
  VideoPlayerController? _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    try {
      await controller.initialize();
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _loading = false;
      });
    } catch (_) {
      await controller.dispose();
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : controller == null
            ? const Text(
                'Video unavailable.',
                style: TextStyle(color: Colors.white),
              )
            : AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    VideoPlayer(controller),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: VideoProgressIndicator(
                        controller,
                        allowScrubbing: true,
                        colors: VideoProgressColors(
                          playedColor: const Color(0xFFFF6B6B),
                          backgroundColor: Colors.white24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _RewardPlaceholder extends StatelessWidget {
  const _RewardPlaceholder({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF0E6),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 42, color: const Color(0xFFFF6B6B)),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF5B3E00),
            ),
          ),
        ],
      ),
    );
  }
}
