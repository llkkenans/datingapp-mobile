import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/feed_notifier.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

const _kBg = Color(0xFF0F0F0F);
const _kSurface = Color(0xFF1C1C1E);
const _kAccent = Color(0xFF6C63FF);
const _kPlaceholder = Color(0xFF2C2C2E);

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not post. Please try again.'),
          backgroundColor: _kSurface,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final username = Supabase.instance.client.auth.currentUser
            ?.userMetadata?['username'] as String? ??
        'you';

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'New Post',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: _kAccent,
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
                        color: _hasContent ? _kAccent : Colors.white24,
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
                const _AvatarPlaceholder(size: 40),
                const SizedBox(width: 10),
                Text(
                  '@$username',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
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
              style: const TextStyle(
                fontSize: 15,
                color: Colors.white,
                height: 1.5,
              ),
              decoration: const InputDecoration(
                hintText: "What's on your mind?",
                hintStyle:
                    TextStyle(fontSize: 15, color: Colors.white38, height: 1.5),
                border: InputBorder.none,
                counterStyle: TextStyle(color: Colors.white24, fontSize: 12),
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
                      child: Image.file(
                        _photoFile!,
                        fit: BoxFit.cover,
                      ),
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
              _PhotoPickerArea(onTap: _pickPhoto),
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
  const _PhotoPickerArea({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Container(
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
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
                  color: _kPlaceholder,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.add_photo_alternate_rounded,
                  color: Colors.white38,
                  size: 26,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Add a photo',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Optional · JPEG, PNG, or WebP · max 5 MB',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white24,
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
    final url = Supabase.instance.client.auth.currentUser
        ?.userMetadata?['avatar_url'] as String?;

    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _Fallback(size: size),
        ),
      );
    }
    return _Fallback(size: size);
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => ClipOval(
        child: Container(
          width: size,
          height: size,
          color: _kPlaceholder,
          child: const Icon(Icons.person_rounded, color: Colors.white38, size: 20),
        ),
      );
}
