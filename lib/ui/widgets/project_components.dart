import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/project.dart';
import '../../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'dusk_ui_components.dart';

/// Horizontal scrolling bar of Project/Space pills for the Captures Feed.
class DuskProjectPillsBar extends StatelessWidget {
  final VoidCallback? onNewProject;

  const DuskProjectPillsBar({
    super.key,
    this.onNewProject,
  });

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final projects = appState.projects;
    final activeId = appState.activeProjectId;
    final p = AppTheme.of(context);
    final totalDumps = appState.todayDumps.length;

    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: 1 + projects.length + 1, // "All" + projects + "+ New"
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          // 1. "All Captures" pill
          if (index == 0) {
            final isSelected = activeId == null;
            return _ProjectPill(
              label: 'All Captures',
              count: totalDumps,
              iconText: '✨',
              isSelected: isSelected,
              accentColor: p.primary,
              onTap: () {
                HapticFeedback.selectionClick();
                appState.setActiveProject(null);
              },
            );
          }

          // 2. "+ New Space" button
          if (index == projects.length + 1) {
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (onNewProject != null) {
                    onNewProject!();
                  } else {
                    showDuskProjectEditorModal(context);
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: p.surface.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: p.outline.withValues(alpha: 0.8),
                      width: 1,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 16, color: p.primary),
                      const SizedBox(width: 4),
                      Text(
                        'New Space',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: p.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          // 3. Project Pill
          final project = projects[index - 1];
          final isSelected = activeId == project.id;
          final count = appState.getDumpCountForProject(project.id);
          final projColor = Color(project.colorValue);

          return _ProjectPill(
            label: project.name,
            count: count,
            iconText: project.icon,
            isSelected: isSelected,
            accentColor: projColor,
            onTap: () {
              HapticFeedback.selectionClick();
              appState.setActiveProject(isSelected ? null : project.id);
            },
            onLongPress: () {
              HapticFeedback.mediumImpact();
              showDuskProjectOptionsSheet(context, project);
            },
          );
        },
      ),
    );
  }
}

class _ProjectPill extends StatelessWidget {
  final String label;
  final int count;
  final String iconText;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ProjectPill({
    required this.label,
    required this.count,
    required this.iconText,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? accentColor.withValues(alpha: 0.16)
                : p.surface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? accentColor.withValues(alpha: 0.8)
                  : p.outline.withValues(alpha: 0.8),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                iconText,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? accentColor : p.onSurface,
                  letterSpacing: -0.2,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accentColor.withValues(alpha: 0.25)
                        : p.onSurface.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? accentColor : p.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact chip used inside Capture screens (Text, Voice, Photo) and Dump Detail screen.
class DuskProjectSelectorChip extends StatelessWidget {
  final String? selectedProjectId;
  final ValueChanged<String?>? onSelected;
  final ValueChanged<String?>? onProjectChanged;
  final bool showLabel;

  const DuskProjectSelectorChip({
    super.key,
    required this.selectedProjectId,
    this.onSelected,
    this.onProjectChanged,
    this.showLabel = true,
  }) : assert(onSelected != null || onProjectChanged != null, 'Either onSelected or onProjectChanged must be supplied');

  ValueChanged<String?> get _callback => onSelected ?? onProjectChanged!;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final project = appState.getProjectById(selectedProjectId);
    final p = AppTheme.of(context);

    final color = project != null ? Color(project.colorValue) : p.onSurfaceVariant;
    final icon = project?.icon ?? '📁';
    final name = project?.name ?? 'Inbox / No Space';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          showDuskProjectPickerSheet(
            context,
            selectedProjectId: selectedProjectId,
            onSelected: _callback,
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: project != null
                ? color.withValues(alpha: 0.12)
                : p.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: project != null
                  ? color.withValues(alpha: 0.45)
                  : p.outline.withValues(alpha: 0.6),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: project != null ? color : p.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 14,
                color: project != null ? color : p.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom modal sheet to choose an active space or unassign.
Future<void> showDuskProjectPickerSheet(
  BuildContext context, {
  required String? selectedProjectId,
  required ValueChanged<String?> onSelected,
}) async {
  final appState = context.read<AppState>();
  final projects = appState.projects;
  final p = AppTheme.of(context);

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: p.outline, width: 1),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Space / Project',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: p.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      showDuskProjectEditorModal(context);
                    },
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('New Space'),
                    style: TextButton.styleFrom(
                      foregroundColor: p.primary,
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Option 1: No Project (Inbox)
              _ProjectPickerTile(
                title: 'No Space (General Feed)',
                iconText: '📥',
                accentColor: p.onSurfaceVariant,
                isSelected: selectedProjectId == null,
                onTap: () {
                  onSelected(null);
                  Navigator.pop(ctx);
                },
              ),
              if (projects.isNotEmpty) ...[
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.45,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: projects.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, idx) {
                      final proj = projects[idx];
                      final isSelected = proj.id == selectedProjectId;
                      final count = appState.getDumpCountForProject(proj.id);
                      final color = Color(proj.colorValue);

                      return _ProjectPickerTile(
                        title: proj.name,
                        iconText: proj.icon,
                        accentColor: color,
                        count: count,
                        subtitle: proj.description,
                        isSelected: isSelected,
                        onTap: () {
                          onSelected(proj.id);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _ProjectPickerTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String iconText;
  final Color accentColor;
  final int? count;
  final bool isSelected;
  final VoidCallback onTap;

  const _ProjectPickerTile({
    required this.title,
    this.subtitle,
    required this.iconText,
    required this.accentColor,
    this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isSelected
                ? accentColor.withValues(alpha: 0.12)
                : p.surfaceVariant.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? accentColor.withValues(alpha: 0.6)
                  : p.outline.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(iconText, style: const TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected ? accentColor : p.onSurface,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: p.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (count != null && count! > 0) ...[
                Text(
                  '$count notes',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: p.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (isSelected)
                Icon(Icons.check_circle_rounded, size: 18, color: accentColor)
              else
                Icon(Icons.chevron_right_rounded, size: 18, color: p.outline),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modal dialog/sheet to create or edit a Project.
Future<Project?> showDuskProjectEditorModal(
  BuildContext context, {
  Project? existingProject,
}) async {
  final appState = context.read<AppState>();
  final p = AppTheme.of(context);
  final isEdit = existingProject != null;

  final nameController =
      TextEditingController(text: existingProject?.name ?? '');
  final descController =
      TextEditingController(text: existingProject?.description ?? '');
  String selectedIcon = existingProject?.icon ?? '📁';
  int selectedColor = existingProject?.colorValue ?? Project.defaultColors[0];

  return await showModalBottomSheet<Project?>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: p.outline, width: 1),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: p.outline,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEdit ? 'Edit Space' : 'Create New Space',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: p.onSurface,
                            letterSpacing: -0.3,
                          ),
                        ),
                        DuskCircleButton(
                          icon: Icons.close_rounded,
                          size: 32,
                          iconSize: 18,
                          onTap: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Icon and Name Input Row
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Color(selectedColor).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Color(selectedColor).withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            selectedIcon,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: nameController,
                            autofocus: !isEdit,
                            textCapitalization: TextCapitalization.sentences,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: p.onSurface,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Space name (e.g. Dusk Launch, Gym)',
                              hintStyle: TextStyle(
                                fontSize: 14,
                                color: p.onSurfaceVariant.withValues(alpha: 0.6),
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              filled: true,
                              fillColor: p.surfaceVariant.withValues(alpha: 0.5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: p.outline),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: p.outline),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Color(selectedColor)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Icon/Emoji Selector Row
                    Text(
                      'Choose Icon',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: p.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: Project.defaultIcons.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, idx) {
                          final icon = Project.defaultIcons[idx];
                          final isCurrent = icon == selectedIcon;
                          return InkWell(
                            onTap: () {
                              setModalState(() => selectedIcon = icon);
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? Color(selectedColor).withValues(alpha: 0.2)
                                    : p.surfaceVariant.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isCurrent
                                      ? Color(selectedColor)
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(icon, style: const TextStyle(fontSize: 18)),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Color Palette Selector Row
                    Text(
                      'Accent Color',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: p.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: Project.defaultColors.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, idx) {
                          final colorVal = Project.defaultColors[idx];
                          final color = Color(colorVal);
                          final isCurrent = colorVal == selectedColor;
                          return InkWell(
                            onTap: () {
                              setModalState(() => selectedColor = colorVal);
                            },
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isCurrent ? p.surface : Colors.transparent,
                                  width: 2.5,
                                ),
                                boxShadow: isCurrent
                                    ? [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.4),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: isCurrent
                                  ? const Icon(
                                      Icons.check_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Description Input
                    TextField(
                      controller: descController,
                      style: TextStyle(fontSize: 13, color: p.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Optional description or goal...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: p.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: p.surfaceVariant.withValues(alpha: 0.35),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: p.outline),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: p.outline),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(selectedColor),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            showDuskSnackBar(
                              context,
                              content: const Text('Please enter a space name'),
                              duration: const Duration(milliseconds: 1500),
                            );
                            return;
                          }

                          if (isEdit) {
                            final updated = existingProject.copyWith(
                              name: name,
                              description: descController.text.trim(),
                              icon: selectedIcon,
                              colorValue: selectedColor,
                              updatedAt: DateTime.now(),
                            );
                            await appState.updateProject(updated);
                            if (ctx.mounted) Navigator.pop(ctx, updated);
                          } else {
                            final created = await appState.createProject(
                              name: name,
                              description: descController.text.trim(),
                              icon: selectedIcon,
                              colorValue: selectedColor,
                            );
                            // Set newly created space active automatically!
                            appState.setActiveProject(created.id);
                            if (ctx.mounted) Navigator.pop(ctx, created);
                          }
                        },
                        child: Text(
                          isEdit ? 'Save Changes' : 'Create Space',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

/// Options bottom sheet when long-pressing a project pill on the feed.
Future<void> showDuskProjectOptionsSheet(
  BuildContext context,
  Project project,
) async {
  final appState = context.read<AppState>();
  final p = AppTheme.of(context);
  final color = Color(project.colorValue);

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: p.outline, width: 1),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(project.icon, style: const TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: p.onSurface,
                          ),
                        ),
                        Text(
                          '${appState.getDumpCountForProject(project.id)} notes • ${appState.getPendingTasksCountForProject(project.id)} pending tasks',
                          style: TextStyle(
                            fontSize: 12,
                            color: p.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.edit_rounded, color: p.primary),
                title: const Text('Edit Space Details'),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () {
                  Navigator.pop(ctx);
                  showDuskProjectEditorModal(context, existingProject: project);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: const Text(
                  'Delete Space',
                  style: TextStyle(color: Colors.redAccent),
                ),
                subtitle: const Text(
                  'Notes will not be deleted; they will move to Inbox',
                  style: TextStyle(fontSize: 11),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dialogCtx) => AlertDialog(
                      backgroundColor: p.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: Text(
                        'Delete "${project.name}"?',
                        style: TextStyle(color: p.onSurface, fontWeight: FontWeight.bold),
                      ),
                      content: Text(
                        'This will delete the space container. All captures and tasks inside will remain safe in your general feed.',
                        style: TextStyle(color: p.onSurfaceVariant, fontSize: 13.5),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx, false),
                          child: Text('Cancel', style: TextStyle(color: p.onSurfaceVariant)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                          ),
                          onPressed: () => Navigator.pop(dialogCtx, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await appState.deleteProject(project.id);
                  }
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
