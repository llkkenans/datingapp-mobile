import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/feed_notifier.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _captionCtrl = TextEditingController();
  final _picker = ImagePicker();
  File? _photoFile;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _captionCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  bool get _hasContent =>
      _captionCtrl.text.trim().isNotEmpty || _photoFile != null;

  Future<void> _pickPhoto() async {
    final xfile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1440,
      imageQuality: 88,
    );
    if (xfile == null) return;
    setState(() => _photoFile = File(xfile.path));
  }

  Future<void> _submit() async {
    if (!_hasContent || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await ref.read(feedNotifierProvider.notifier).createPost(
            caption: _captionCtrl.text.trim().isEmpty
                ? null
                : _captionCtrl.text.trim(),
            photoFile: _photoFile,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      final cs = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not post. Please try again.'),
          backgroundColor: cs.surfaceContainerHighest,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final username = Supabase.instance.client.auth.currentUser
            ?.userMetadata?['username'] as String? ??
        'you';

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: cs.onSurface, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'New Post',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _isSubmitting
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: cs.primary,
                      strokeWidth: 2,
                    ),
                  )
                : TextButton(
                    onPressed: _hasContent ? _submit : null,
                    child: Text(
                      'Post',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _hasContent
                            ? cs.primary
                            : cs.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author preview row
            Row(
              children: [
                _AvatarPlaceholder(size: 40),
                const SizedBox(width: 10),
                Text(
                  '@$username',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Caption field
            TextField(
              controller: _captionCtrl,
              maxLines: null,
              minLines: 3,
              maxLength: 2000,
              style: TextStyle(
                fontSize: 15,
                color: cs.onSurface,
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText: "What's on your mind?",
                hintStyle: TextStyle(
                    fontSize: 15,
                    color: cs.onSurfaceVariant,
                    height: 1.5),
                border: InputBorder.none,
                counterStyle: TextStyle(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    fontSize: 12),
                contentPadding: EdgeInsets.zero,
              ),
            ),

            const SizedBox(height: 16),

            // Photo area
            if (_photoFile != null) ...[
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 4 / 5,
                      child: Image.file(_photoFile!, fit: BoxFit.cover),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => _photoFile = null),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          // overlay on top of a photo — semantic black is correct
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ] else ...[
              _PhotoPickerArea(onTap: _pickPhoto, cs: cs),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Photo picker placeholder ─────────────────────────────────────────────────

class _PhotoPickerArea extends StatelessWidget {
  const _PhotoPickerArea({required this.onTap, required this.cs});
  final VoidCallback onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: cs.outline,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.add_photo_alternate_rounded,
                  color: cs.onSurfaceVariant,
                  size: 26,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Add a photo',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Optional · JPEG, PNG, or WebP · max 5 MB',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Current-user avatar placeholder ─────────────────────────────────────────

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final url = Supabase.instance.client.auth.currentUser
        ?.userMetadata?['avatar_url'] as String?;

    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _Fallback(size: size, cs: cs),
        ),
      );
    }
    return _Fallback(size: size, cs: cs);
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.size, required this.cs});
  final double size;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) => ClipOval(
        child: Container(
          width: size,
          height: size,
          color: cs.surfaceContainerHighest,
          child: Icon(Icons.person_rounded,
              color: cs.onSurfaceVariant, size: 20),
        ),
      );
}
