import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../services/supabase_service.dart';
import '../widgets/dusk_ui_components.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _professionController;

  DateTime? _selectedDob;
  bool _clearDob = false;

  File? _pickedImageFile;
  String? _existingLocalPath;
  String? _existingRemoteUrl;
  bool _clearAvatar = false;

  bool _isSaving = false;
  String? _nameError;

  static const List<String> _professionSuggestions = [
    'Designer',
    'Software Engineer',
    'Founder',
    'Student',
    'Product Manager',
    'Writer',
    'Creator',
    'Researcher',
    'Educator',
    'Healthcare',
  ];

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    final initialName = appState.preferredName == 'Friend'
        ? ''
        : appState.preferredName;
    _nameController = TextEditingController(text: initialName);
    _professionController = TextEditingController(text: appState.profession);
    _selectedDob = appState.dob;
    _existingLocalPath = appState.avatarLocalPath;
    _existingRemoteUrl = appState.avatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _professionController.dispose();
    super.dispose();
  }

  bool get _hasPhoto {
    if (_clearAvatar) return false;
    if (_pickedImageFile != null) return true;
    if (_existingLocalPath != null &&
        _existingLocalPath!.isNotEmpty &&
        File(_existingLocalPath!).existsSync()) {
      return true;
    }
    if (_existingRemoteUrl != null && _existingRemoteUrl!.isNotEmpty) {
      return true;
    }
    return false;
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: source,
        maxWidth: 900,
        maxHeight: 900,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() {
          _pickedImageFile = File(picked.path);
          _clearAvatar = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not select photo: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showPhotoOptionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF9F7F2),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
            22,
            12,
            22,
            MediaQuery.of(ctx).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDD6CA),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Profile Photo',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1B1A19),
                            letterSpacing: -0.4,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Choose how you want to appear in Dusk',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF88827A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  DuskCircleButton(
                    icon: Icons.close_rounded,
                    size: 36,
                    iconSize: 18,
                    onTap: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _buildSheetOption(
                icon: Icons.camera_alt_rounded,
                iconBg: const Color(0xFFFDE8D7),
                iconColor: const Color(0xFFFF7A1A),
                title: 'Take a Photo',
                subtitle: 'Use your camera to snap a new profile picture',
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickPhoto(ImageSource.camera);
                },
              ),
              const SizedBox(height: 10),
              _buildSheetOption(
                icon: Icons.photo_library_rounded,
                iconBg: const Color(0xFFE8F1FC),
                iconColor: const Color(0xFF4A84D8),
                title: 'Choose from Gallery',
                subtitle: 'Pick a photo from your library',
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickPhoto(ImageSource.gallery);
                },
              ),
              if (_hasPhoto) ...[
                const SizedBox(height: 10),
                _buildSheetOption(
                  icon: Icons.delete_outline_rounded,
                  iconBg: const Color(0xFFFEECEB),
                  iconColor: const Color(0xFFD9383A),
                  title: 'Remove Photo',
                  subtitle: 'Use your monogram initial instead',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    setState(() {
                      _pickedImageFile = null;
                      _existingLocalPath = null;
                      _existingRemoteUrl = null;
                      _clearAvatar = true;
                    });
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSheetOption({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEFE8DE)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B1A19),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF88827A),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFA59F95),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _selectedDob ?? DateTime(now.year - 25, 6, 15);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: 'SELECT DATE OF BIRTH',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFF7A1A),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1B1A19),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDob = picked;
        _clearDob = false;
      });
    }
  }

  int? _calculateAge(DateTime? dob) {
    if (dob == null) return null;
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age >= 0 ? age : null;
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _nameError = 'Please enter what we should call you';
      });
      return;
    }

    setState(() {
      _nameError = null;
      _isSaving = true;
    });

    try {
      await context.read<AppState>().saveUserProfile(
            preferredName: name,
            profession: _professionController.text.trim(),
            dob: _selectedDob,
            newAvatarFile: _pickedImageFile,
            clearDob: _clearDob,
            clearAvatar: _clearAvatar,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 19),
                SizedBox(width: 10),
                Text('Profile updated successfully'),
              ],
            ),
            backgroundColor: const Color(0xFF1B1A19),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildAvatarPreview(String displayInitial) {
    ImageProvider? imageProvider;
    if (!_clearAvatar) {
      if (_pickedImageFile != null && _pickedImageFile!.existsSync()) {
        imageProvider = FileImage(_pickedImageFile!);
      } else if (_existingLocalPath != null &&
          _existingLocalPath!.isNotEmpty &&
          File(_existingLocalPath!).existsSync()) {
        imageProvider = FileImage(File(_existingLocalPath!));
      } else if (_existingRemoteUrl != null &&
          _existingRemoteUrl!.isNotEmpty) {
        imageProvider = NetworkImage(_existingRemoteUrl!);
      }
    }

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _showPhotoOptionsSheet,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: imageProvider == null
                        ? const LinearGradient(
                            colors: [Color(0xFFFF9B50), Color(0xFFFF7A1A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: imageProvider != null ? Colors.white : null,
                    border: Border.all(
                      color: Colors.white,
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF7A1A).withValues(alpha: 0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    image: imageProvider != null
                        ? DecorationImage(
                            image: imageProvider,
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: imageProvider == null
                      ? Center(
                          child: Text(
                            displayInitial,
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1A19),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _showPhotoOptionsSheet,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFEAE3D8)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.photo_camera_back_rounded,
                    size: 15,
                    color: Color(0xFFFF7A1A),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _hasPhoto ? 'Change Profile Photo' : 'Upload Photo',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B1A19),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService().currentUser;
    final email = user?.email ?? 'mindful@dusk.app';
    final typedName = _nameController.text.trim();
    final initial = typedName.isNotEmpty ? typedName[0].toUpperCase() : 'D';
    final age = _calculateAge(_selectedDob);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F2),
      body: DuskAmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    DuskCircleButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      size: 42,
                      iconSize: 18,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const Text(
                      'Personal Profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B1A19),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 42),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildAvatarPreview(initial)
                          .animate()
                          .fadeIn(duration: 350.ms)
                          .scale(begin: const Offset(0.95, 0.95)),

                      const SizedBox(height: 26),

                      // Preferred Name Card (Required)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: _nameError != null
                                ? const Color(0xFFD9383A)
                                : const Color(0xFFF0EBE1),
                            width: _nameError != null ? 1.5 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.wb_twilight_rounded,
                                  size: 18,
                                  color: Color(0xFFFF7A1A),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'What should I call you?',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1B1A19),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                DuskPillBadge(
                                  text: 'Required',
                                  variant: DuskBadgeVariant.peach,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Used in your daily greetings and personal reflection cards.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF88827A),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _nameController,
                              textCapitalization: TextCapitalization.words,
                              onChanged: (_) {
                                setState(() {
                                  if (_nameError != null &&
                                      _nameController.text.trim().isNotEmpty) {
                                    _nameError = null;
                                  }
                                });
                              },
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1B1A19),
                              ),
                              decoration: InputDecoration(
                                hintText: 'e.g. Alex, Maya, Sam...',
                                fillColor: const Color(0xFFFAF7F2),
                                prefixIcon: const Icon(
                                  Icons.person_outline_rounded,
                                  color: Color(0xFFFF7A1A),
                                  size: 20,
                                ),
                                errorText: _nameError,
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 80.ms, duration: 350.ms).slideY(begin: 0.04),

                      const SizedBox(height: 16),

                      // Profession Card (Optional)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFF0EBE1)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.work_outline_rounded,
                                  size: 18,
                                  color: Color(0xFF4A84D8),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Profession / Craft',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1B1A19),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                DuskPillBadge(
                                  text: 'Optional',
                                  variant: DuskBadgeVariant.neutral,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Helps Dusk contextualize your work thoughts and daily rhythm.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF88827A),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _professionController,
                              textCapitalization: TextCapitalization.words,
                              onChanged: (_) => setState(() {}),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1B1A19),
                              ),
                              decoration: InputDecoration(
                                hintText: 'What do you do?',
                                fillColor: const Color(0xFFFAF7F2),
                                prefixIcon: const Icon(
                                  Icons.badge_outlined,
                                  color: Color(0xFF4A84D8),
                                  size: 20,
                                ),
                                suffixIcon: _professionController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          size: 18,
                                          color: Color(0xFFA59F95),
                                        ),
                                        onPressed: () {
                                          _professionController.clear();
                                          setState(() {});
                                        },
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _professionSuggestions.map((role) {
                                final isSelected = _professionController.text
                                        .trim()
                                        .toLowerCase() ==
                                    role.toLowerCase();
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _professionController.text = role;
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFFE8F1FC)
                                          : const Color(0xFFF7F4EE),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF4A84D8)
                                            : const Color(0xFFEAE3D8),
                                      ),
                                    ),
                                    child: Text(
                                      role,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? const Color(0xFF205295)
                                            : const Color(0xFF6E6862),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 150.ms, duration: 350.ms).slideY(begin: 0.04),

                      const SizedBox(height: 16),

                      // Date of Birth Card (Optional)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFF0EBE1)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.cake_outlined,
                                  size: 18,
                                  color: Color(0xFF2DC48D),
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Date of Birth',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1B1A19),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (age != null) ...[
                                  DuskPillBadge(
                                    text: '$age yrs',
                                    variant: DuskBadgeVariant.green,
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                const DuskPillBadge(
                                  text: 'Optional',
                                  variant: DuskBadgeVariant.neutral,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            InkWell(
                              onTap: _pickDob,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAF7F2),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFECE7DE),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today_rounded,
                                      size: 19,
                                      color: Color(0xFF2DC48D),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _selectedDob != null
                                            ? DateFormat('MMMM d, yyyy')
                                                .format(_selectedDob!)
                                            : 'Select your date of birth',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: _selectedDob != null
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: _selectedDob != null
                                              ? const Color(0xFF1B1A19)
                                              : const Color(0xFFAAA398),
                                        ),
                                      ),
                                    ),
                                    if (_selectedDob != null)
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedDob = null;
                                            _clearDob = true;
                                          });
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.only(right: 6),
                                          child: Icon(
                                            Icons.close_rounded,
                                            size: 18,
                                            color: Color(0xFFA59F95),
                                          ),
                                        ),
                                      ),
                                    const Icon(
                                      Icons.unfold_more_rounded,
                                      size: 18,
                                      color: Color(0xFFA59F95),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 220.ms, duration: 350.ms).slideY(begin: 0.04),

                      const SizedBox(height: 16),

                      // Account Email Card (Read-only)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFF0EBE1)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3EFE9),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: const Icon(
                                Icons.mail_outline_rounded,
                                size: 19,
                                color: Color(0xFF6E6862),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Account Email',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF88827A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    email,
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1B1A19),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.lock_outline_rounded,
                              size: 17,
                              color: Color(0xFFBEB7AC),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 280.ms, duration: 350.ms),

                      const SizedBox(height: 28),

                      DuskPrimaryButton(
                        label: 'Save Profile Changes',
                        icon: Icons.check_rounded,
                        isLoading: _isSaving,
                        onPressed: _saveProfile,
                      ).animate().fadeIn(delay: 320.ms, duration: 350.ms),
                    ],
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
