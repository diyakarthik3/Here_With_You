import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:here_with_you/main.dart';
import 'package:here_with_you/screens/admin_dashboard_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:here_with_you/services/admin_media_service.dart';
import 'package:here_with_you/screens/manage_user_profile_screen.dart';
import 'package:here_with_you/widgets/media_source_picker.dart';

class AdminMediaUploadScreen extends StatefulWidget {
  const AdminMediaUploadScreen({super.key});

  @override
  State<AdminMediaUploadScreen> createState() => _AdminMediaUploadScreenState();
}

class _AdminMediaUploadScreenState extends State<AdminMediaUploadScreen> {
  final AdminMediaService _mediaService = AdminMediaService.instance;
  final ImagePicker _imagePicker = ImagePicker();

  bool _isPicking = false;
  bool _isSending = false;
  int _selectedControlIndex = 0;

  @override
  void initState() {
    super.initState();
    _mediaService.refreshFromBackend();
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

  String get _activeControlLabel {
    switch (_selectedControlIndex) {
      case 0:
        return 'Uploads';
      case 1:
        return 'Sources';
      case 2:
        return 'Publish';
      case 3:
        return 'Manage user profile';
      case 4:
        return 'Dashboard';
      default:
        return 'Uploads';
    }
  }

  Future<void> _handleSourceSelection(MediaUploadSource source) async {
    if (_isPicking) return;

    setState(() => _isPicking = true);

    try {
      switch (source) {
        case MediaUploadSource.cameraRoll:
          await _pickFromCameraRoll();
          break;
        case MediaUploadSource.localFiles:
          await _pickFromLocalFiles();
          break;
        case MediaUploadSource.googlePhotos:
          await _addGooglePhotosPlaceholder();
          break;
      }
    } finally {
      if (mounted) {
        setState(() => _isPicking = false);
      }
    }
  }

  Future<void> _pickFromCameraRoll() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final bytes = await image.readAsBytes();
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
      const SnackBar(content: Text('Image added from camera roll.')),
    );
  }

  Future<void> _pickFromLocalFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final picked = result.files.first;
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
      const SnackBar(content: Text('Image added from local files.')),
    );
  }

  Future<void> _addGooglePhotosPlaceholder() async {
    await _mediaService.addGooglePhotosPlaceholder();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Google Photos API placeholder added. Integrate API next.',
        ),
      ),
    );
  }

  Future<void> _sendToBackendPlaceholder() async {
    if (_isSending) return;

    setState(() => _isSending = true);

    try {
      final count = await _mediaService.sendToBackendPlaceholder();
      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      await _mediaService.refreshFromBackend();

      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(content: Text('$count images synced to Firestore.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Control Center'),
        backgroundColor: const Color(0xFFFF6B6B),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back to Login',
          onPressed: _goToLoginScreen,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5F0),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MediaSourcePicker(onSourceSelected: _handleSourceSelection),
                  const SizedBox(height: 12),
                  Text(
                    _isPicking
                        ? 'Opening picker...'
                        : 'Active control: $_activeControlLabel. Select photos to customize game puzzles and rewards.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ValueListenableBuilder<List<UploadedMediaFile>>(
                valueListenable: _mediaService.uploadedFiles,
                builder: (context, files, _) {
                  if (files.isEmpty) {
                    return Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFFFD7CC)),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Text(
                        'No photos uploaded yet.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: files.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final file = files[index];
                      return _UploadedMediaTile(
                        file: file,
                        onRemove: () =>
                            _mediaService.removeUploadedFile(file.id),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isSending ? null : _sendToBackendPlaceholder,
                icon: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_rounded),
                label: Text(_isSending ? 'Syncing...' : 'Sync to Firestore'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B6B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFFFFF0E6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: _BottomControlButton(
                  label: 'Uploads',
                  icon: Icons.photo_library_rounded,
                  selected: _selectedControlIndex == 0,
                  onTap: () => setState(() => _selectedControlIndex = 0),
                ),
              ),
              Expanded(
                child: _BottomControlButton(
                  label: 'Sources',
                  icon: Icons.widgets_rounded,
                  selected: _selectedControlIndex == 1,
                  onTap: () => setState(() => _selectedControlIndex = 1),
                ),
              ),
              Expanded(
                child: _BottomControlButton(
                  label: 'Publish',
                  icon: Icons.cloud_done_rounded,
                  selected: _selectedControlIndex == 2,
                  onTap: () => setState(() => _selectedControlIndex = 2),
                ),
              ),
              Expanded(
                child: _BottomControlButton(
                  label: 'Manage user profile',
                  icon: Icons.group_add_rounded,
                  selected: _selectedControlIndex == 3,
                  onTap: () {
                    setState(() => _selectedControlIndex = 3);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ManageUserProfileScreen(),
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: _BottomControlButton(
                  label: 'Dashboard',
                  icon: Icons.dashboard_rounded,
                  selected: _selectedControlIndex == 4,
                  onTap: () {
                    setState(() => _selectedControlIndex = 4);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminDashboard(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomControlButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _BottomControlButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(
        icon,
        color: selected ? const Color(0xFFFF6B6B) : Colors.black54,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: selected ? const Color(0xFFFF6B6B) : Colors.black54,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

class _UploadedMediaTile extends StatelessWidget {
  final UploadedMediaFile file;
  final VoidCallback onRemove;

  const _UploadedMediaTile({required this.file, required this.onRemove});

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

  @override
  Widget build(BuildContext context) {
    final Uint8List? bytes = file.bytes;
    final String? url = file.downloadUrl;

    return Container(
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
              child: bytes != null && bytes.isNotEmpty
                  ? Image.memory(bytes, fit: BoxFit.cover)
                  : (url != null && url.isNotEmpty
                        ? Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: const Color(0xFFFFEEE7),
                              alignment: Alignment.center,
                              child: const Icon(Icons.image_outlined),
                            ),
                          )
                        : Container(
                            color: const Color(0xFFFFEEE7),
                            alignment: Alignment.center,
                            child: const Icon(Icons.image_outlined),
                          )),
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
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}
