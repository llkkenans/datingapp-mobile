import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/onboarding_providers.dart';
import '../widgets/onboarding_button.dart';

class StepPhoto extends ConsumerStatefulWidget {
  const StepPhoto({super.key});

  @override
  ConsumerState<StepPhoto> createState() => _StepPhotoState();
}

class _StepPhotoState extends ConsumerState<StepPhoto> {
  final _picker = ImagePicker();
  bool _uploading = false;
  String? _uploadError;
  String? _localPath;

  @override
  void initState() {
    super.initState();
    // If already uploaded (user went back and came forward), show it.
    final saved = ref.read(onboardingProvider).form.avatarUrl;
    if (saved != null) {
      // avatarUrl means a prior upload succeeded; no local path available.
    }
  }

  Future<void> _pick(ImageSource source) async {
    final xFile = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (xFile == null || !mounted) return;

    setState(() {
      _localPath = xFile.path;
      _uploading = true;
      _uploadError = null;
    });

    try {
      await ref.read(onboardingProvider.notifier).uploadAvatar(File(xFile.path));
      if (mounted) setState(() => _uploading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _uploadError = 'Upload failed. Tap to try again.';
      });
    }
  }

  void _showPickerSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Colors.white70),
              title: const Text('Choose from gallery',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pick(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: Colors.white70),
              title: const Text('Take a photo',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pick(ImageSource.camera);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = ref.watch(onboardingProvider).form.avatarUrl;
    final hasPhoto = avatarUrl != null || _localPath != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add a profile photo',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Profiles with photos get significantly more matches.',
                  style: TextStyle(fontSize: 15, color: Colors.white54),
                ),
                const SizedBox(height: 40),
                Center(
                  child: GestureDetector(
                    onTap: _showPickerSheet,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        _Avatar(
                          localPath: _localPath,
                          networkUrl: avatarUrl,
                          uploading: _uploading,
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF6C63FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt,
                              color: Colors.white, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_uploadError != null) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      _uploadError!,
                      style: const TextStyle(
                          color: Color(0xFFEF5350), fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                if (hasPhoto && !_uploading) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton.icon(
                      onPressed: _showPickerSheet,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Change photo'),
                      style: TextButton.styleFrom(
                          foregroundColor: Colors.white54),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: OnboardingButton(
            label: 'Continue',
            enabled: hasPhoto && !_uploading,
            loading: _uploading,
            onPressed: ref.read(onboardingProvider.notifier).nextStep,
          ),
        ),
        Center(
          child: TextButton(
            onPressed: _uploading
                ? null
                : ref.read(onboardingProvider.notifier).nextStep,
            child: const Text(
              'Skip for now',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.localPath,
    required this.networkUrl,
    required this.uploading,
  });

  final String? localPath;
  final String? networkUrl;
  final bool uploading;

  @override
  Widget build(BuildContext context) {
    const size = 130.0;

    Widget image;
    if (localPath != null) {
      image = Image.file(File(localPath!), fit: BoxFit.cover);
    } else if (networkUrl != null) {
      image = Image.network(networkUrl!, fit: BoxFit.cover);
    } else {
      image = const Icon(Icons.person, size: 60, color: Colors.white24);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white12, width: 2),
      ),
      child: ClipOval(
        child: uploading
            ? const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
                ),
              )
            : image,
      ),
    );
  }
}
