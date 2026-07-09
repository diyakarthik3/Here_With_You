import 'package:flutter/material.dart';
import 'package:here_with_you/services/admin_media_service.dart';

class MediaSourcePicker extends StatelessWidget {
  final ValueChanged<MediaUploadSource> onSourceSelected;

  const MediaSourcePicker({
    super.key,
    required this.onSourceSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Choose image source',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _SourceButton(
              icon: Icons.photo_library_rounded,
              label: 'Camera Roll',
              onTap: () => onSourceSelected(MediaUploadSource.cameraRoll),
            ),
            _SourceButton(
              icon: Icons.folder_open_rounded,
              label: 'Local Files',
              onTap: () => onSourceSelected(MediaUploadSource.localFiles),
            ),
            _SourceButton(
              icon: Icons.cloud_upload_rounded,
              label: 'Google Photos',
              onTap: () => onSourceSelected(MediaUploadSource.googlePhotos),
            ),
          ],
        ),
      ],
    );
  }
}

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
