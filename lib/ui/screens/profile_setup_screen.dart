import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../services/supabase_service.dart';
import '../widgets/dusk_ui_components.dart';
import 'reflection_schedule_setup_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  final bool isPreview;

  const ProfileSetupScreen({super.key, this.isPreview = false});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _professionController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();

  DateTime? _selectedDob;
  File? _pickedAvatarFile;
  bool _isSaving = false;
  String? _nameError;

  static const List<String> _professionChips = [
    'Student',
    'Designer',
    'Software Engineer',
    'Founder',
    'Product Manager',
    'Writer',
    'Creator',
    'Researcher',
    'Healthcare',
  ];

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    final user = SupabaseService().currentUser;
    final meta = user?.userMetadata ?? {};
    final metaName =
        (meta['preferred_name'] ?? meta['full_name'])?.toString().trim() ?? '';
    final existingName = widget.isPreview && appState.preferredName != 'Friend'
        ? appState.preferredName
        : metaName;
    if (existingName.trim().isNotEmpty) {
      _nameController.text = existingName.trim();
    }
    if (appState.profession.isNotEmpty) {
      _professionController.text = appState.profession;
    }
    _selectedDob = appState.dob;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _professionController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  String _timeOfDayGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Morning';
    if (h < 17) return 'Afternoon';
    return 'Evening';
  }

  Future<void> _pickAvatar() async {
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
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDD6CA),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Add a Profile Photo',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B1A19),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                tileColor: Colors.white,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFDE8D7),
                  child: Icon(Icons.camera_alt_rounded, color: Color(0xFFFF7A1A)),
                ),
                title: const Text(
                  'Take a Photo',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final picked = await ImagePicker().pickImage(
                    source: ImageSource.camera,
                    maxWidth: 900,
                    maxHeight: 900,
                    imageQuality: 85,
                  );
                  if (picked != null && mounted) {
                    setState(() => _pickedAvatarFile = File(picked.path));
                  }
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                tileColor: Colors.white,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F1FC),
                  child: Icon(Icons.photo_library_rounded, color: Color(0xFF4A84D8)),
                ),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final picked = await ImagePicker().pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 900,
                    maxHeight: 900,
                    imageQuality: 85,
                  );
                  if (picked != null && mounted) {
                    setState(() => _pickedAvatarFile = File(picked.path));
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _selectedDob ?? DateTime(now.year - 24, 6, 15);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: 'SELECT YOUR DATE OF BIRTH',
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
      setState(() => _selectedDob = picked);
    }
  }

  Future<void> _submit({required bool skipOptional}) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _nameError = 'Please tell us what we should call you (Required)';
      });
      _nameFocusNode.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your preferred name is required. Profession and DOB are optional.',
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1B1A19),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      );
      return;
    }

    setState(() {
      _nameError = null;
      _isSaving = true;
    });

    try {
      await context.read<AppState>().saveUserProfile(
            preferredName: name,
            profession: skipOptional ? '' : _professionController.text.trim(),
            dob: skipOptional ? null : _selectedDob,
            newAvatarFile: _pickedAvatarFile,
            clearDob: skipOptional,
          );

      if (!mounted) return;
      if (widget.isPreview) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const ReflectionScheduleSetupScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final typedName = _nameController.text.trim();
    final previewName = typedName.isEmpty ? 'Friend' : typedName;
    final initial = previewName[0].toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F2),
      body: DuskAmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Top Step Bar (Overflow-safe on narrow screens and large text scales)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                child: Row(
                  children: [
                    if (widget.isPreview) ...[
                      DuskCircleButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        size: 38,
                        iconSize: 16,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 10),
                    ],
                    const Flexible(
                      child: DuskPillBadge(
                        text: 'STEP 1 OF 2',
                        variant: DuskBadgeVariant.peach,
                        icon: Icons.auto_awesome_rounded,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _isSaving
                          ? null
                          : () => _submit(skipOptional: true),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF6E6862),
                        backgroundColor: Colors.white.withValues(alpha: 0.75),
                        minimumSize: const Size(0, 34),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: const BorderSide(color: Color(0xFFEBE5DC)),
                        ),
                      ),
                      child: const Text(
                        'Skip optional',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Live Greeting & Avatar Badge
                      Center(
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _pickAvatar,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: _pickedAvatarFile == null
                                          ? const LinearGradient(
                                              colors: [
                                                Color(0xFFFF9B50),
                                                Color(0xFFFF7A1A),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            )
                                          : null,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 3.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFF7A1A)
                                              .withValues(alpha: 0.2),
                                          blurRadius: 18,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                      image: _pickedAvatarFile != null
                                          ? DecorationImage(
                                              image: FileImage(
                                                _pickedAvatarFile!,
                                              ),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: _pickedAvatarFile == null
                                        ? Center(
                                            child: Text(
                                              initial,
                                              style: const TextStyle(
                                                fontSize: 30,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                              ),
                                            ),
                                          )
                                        : null,
                                  ),
                                  Positioned(
                                    bottom: -2,
                                    right: -2,
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1B1A19),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.add_a_photo_rounded,
                                        size: 13,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFEDE6DA),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.wb_twilight_rounded,
                                    size: 14,
                                    color: Color(0xFFFF7A1A),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      '"${_timeOfDayGreeting()}, $previewName"',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF6E6862),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 380.ms).scale(begin: const Offset(0.96, 0.96)),

                      const SizedBox(height: 16),

                      const Text(
                        'What should I call you?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1B1A19),
                          letterSpacing: -0.6,
                          height: 1.2,
                        ),
                      ).animate().fadeIn(delay: 60.ms, duration: 380.ms).slideY(begin: 0.05),

                      const SizedBox(height: 6),

                      const Text(
                        'Only your preferred name is required—profession and birthday are optional and skippable.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF88827A),
                          height: 1.4,
                        ),
                      ).animate().fadeIn(delay: 120.ms, duration: 380.ms).slideY(begin: 0.05),

                      const SizedBox(height: 20),

                      // 1. Preferred Name (Required)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: _nameError != null
                                ? const Color(0xFFD9383A)
                                : const Color(0xFFFF7A1A).withValues(alpha: 0.45),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF7A1A).withValues(alpha: 0.05),
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
                                Expanded(
                                  child: Text(
                                    'Preferred Name',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14.5,
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
                            const SizedBox(height: 10),
                            TextField(
                              controller: _nameController,
                              focusNode: _nameFocusNode,
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
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1B1A19),
                              ),
                              decoration: InputDecoration(
                                hintText: 'What should I call you?',
                                fillColor: const Color(0xFFFAF7F2),
                                prefixIcon: const Icon(
                                  Icons.person_rounded,
                                  color: Color(0xFFFF7A1A),
                                  size: 20,
                                ),
                                errorText: _nameError,
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 160.ms, duration: 380.ms).slideY(begin: 0.04),

                      const SizedBox(height: 14),

                      // 2. Profession (Optional / Skippable)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFEFE8DE)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Your Profession',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
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
                            const SizedBox(height: 10),
                            TextField(
                              controller: _professionController,
                              textCapitalization: TextCapitalization.words,
                              onChanged: (_) => setState(() {}),
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1B1A19),
                              ),
                              decoration: InputDecoration(
                                hintText: 'e.g. Designer, Student, Founder...',
                                fillColor: const Color(0xFFFAF7F2),
                                prefixIcon: const Icon(
                                  Icons.work_outline_rounded,
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
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _professionChips.map((chip) {
                                final isSelected = _professionController.text
                                        .trim()
                                        .toLowerCase() ==
                                    chip.toLowerCase();
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _professionController.text = chip;
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFFE8F1FC)
                                          : const Color(0xFFF7F4EE),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF4A84D8)
                                            : const Color(0xFFEAE3D8),
                                      ),
                                    ),
                                    child: Text(
                                      chip,
                                      style: TextStyle(
                                        fontSize: 11.5,
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
                      ).animate().fadeIn(delay: 220.ms, duration: 380.ms).slideY(begin: 0.04),

                      const SizedBox(height: 14),

                      // 3. Date of Birth (Optional / Skippable)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFEFE8DE)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Date of Birth',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
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
                            const SizedBox(height: 10),
                            InkWell(
                              onTap: _pickDob,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 13,
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
                                      Icons.cake_outlined,
                                      size: 19,
                                      color: Color(0xFF2DC48D),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _selectedDob != null
                                            ? DateFormat('MMMM d, yyyy')
                                                .format(_selectedDob!)
                                            : 'Select your date of birth',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14.5,
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
                                        onTap: () =>
                                            setState(() => _selectedDob = null),
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
                                      Icons.calendar_month_rounded,
                                      size: 18,
                                      color: Color(0xFFA59F95),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 280.ms, duration: 380.ms).slideY(begin: 0.04),

                      const SizedBox(height: 22),

                      DuskPrimaryButton(
                        label: 'Continue',
                        icon: Icons.arrow_forward_rounded,
                        isLoading: _isSaving,
                        onPressed: () => _submit(skipOptional: false),
                      ).animate().fadeIn(delay: 340.ms, duration: 380.ms),

                      const SizedBox(height: 6),

                      Center(
                        child: TextButton(
                          onPressed: _isSaving
                              ? null
                              : () => _submit(skipOptional: true),
                          child: const Text(
                            'Save name & skip optional details',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF88827A),
                            ),
                          ),
                        ),
                      ).animate().fadeIn(delay: 380.ms, duration: 380.ms),
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
