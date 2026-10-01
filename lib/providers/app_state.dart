import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/dump.dart';
import '../models/reflection_cycle.dart';
import '../models/reflection_ritual.dart';
import '../models/task_item.dart';
import '../models/project.dart';
import '../services/local_db_service.dart';
import '../services/supabase_service.dart';
import '../services/capture_service.dart';
import '../services/notification_service.dart';
import '../services/quick_capture_service.dart';
import '../services/task_service.dart';
import '../services/subscription_service.dart';
import '../ui/theme/app_theme.dart';

class AppState extends ChangeNotifier {
  static const String colorThemePrefKey = 'app_color_theme_id';

  final LocalDbService _localDb = LocalDbService();
  final Uuid _uuid = const Uuid();
  final SubscriptionService _subscription = SubscriptionService();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<AuthState>? _authSubscription;
  String? _activeUserId;

  // Monetization & Subscription Rules (RevenueCat)
  bool get isPro => _subscription.isPro;

  static const int freeDailyDumpLimit = 20;
  static const int freeMaxAudioSeconds = 60;
  static const int proMaxAudioSeconds = 600;
  static const int freeHistoryDaysLimit = 14;

  int get maxAudioSeconds => isPro ? proMaxAudioSeconds : freeMaxAudioSeconds;

  int get todayDumpsCount {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _todayDumps.where((d) {
      final capStr = d['captured_at']?.toString() ?? d['created_at']?.toString();
      if (capStr == null) return true;
      final dt = DateTime.tryParse(capStr);
      if (dt == null) return true;
      final local = dt.toLocal();
      return DateTime(local.year, local.month, local.day) == today;
    }).length;
  }

  bool get canCaptureDump => isPro || todayDumpsCount < freeDailyDumpLimit;
  int get remainingDumpsToday => isPro ? 999999 : (freeDailyDumpLimit - todayDumpsCount).clamp(0, freeDailyDumpLimit);

  bool get isCloudSyncEnabled => isPro && SupabaseService().currentUser != null;

  DateTime get freeHistoryCutoff => DateTime.now().subtract(const Duration(days: freeHistoryDaysLimit));

  bool _hasCompletedReflectionToday = false;
  bool get hasCompletedReflectionToday => _hasCompletedReflectionToday;
  bool get canStartReflection => isPro || !_hasCompletedReflectionToday;

  void markReflectionCompletedToday() {
    _hasCompletedReflectionToday = true;
    notifyListeners();
  }

  AppColorThemeId _colorTheme = AppTheme.activeThemeId;
  AppColorThemeId get colorTheme => _colorTheme;
  DuskColorPalette get palette => _colorTheme.palette;

  List<Dump> _pendingDumps = [];
  List<Dump> get pendingDumps => _pendingDumps;

  List<Map<String, dynamic>> _todayDumps = [];
  List<Map<String, dynamic>> get todayDumps => _todayDumps;
  List<Map<String, dynamic>> get allDumps => _todayDumps;

  List<Project> _projects = [];
  List<Project> get projects => List.unmodifiable(_projects);

  String? _activeProjectId;
  String? get activeProjectId => _activeProjectId;

  Project? get activeProject {
    if (_activeProjectId == null) return null;
    final idx = _projects.indexWhere((p) => p.id == _activeProjectId);
    return idx != -1 ? _projects[idx] : null;
  }

  Project? getProjectById(String? id) {
    if (id == null || id.isEmpty) return null;
    final idx = _projects.indexWhere((p) => p.id == id);
    return idx != -1 ? _projects[idx] : null;
  }

  int getDumpCountForProject(String? projectId) {
    if (projectId == null) return _todayDumps.length;
    return _todayDumps.where((d) => d['project_id'] == projectId).length;
  }

  int getPendingTasksCountForProject(String? projectId) {
    if (projectId == null) return pendingTasksCount;
    return _tasks.where((t) => t.isPending && t.projectId == projectId).length;
  }

  List<TaskItem> _tasks = [];
  List<TaskItem> get tasks => _tasks;
  int get pendingTasksCount => _tasks.where((t) => t.isPending).length;

  List<String> _customTags = [];
  List<String> get customTags => List.unmodifiable(_customTags);

  List<String> get availableTags {
    final combined = <String>[
      ...Dump.defaultTags,
      ..._customTags,
      for (final d in _todayDumps) ...Dump.parseTags(d['tags']),
      for (final t in _tasks) ...t.tags,
    ];
    return Dump.parseTags(combined);
  }

  ReflectionCycle? _currentCycle;
  ReflectionCycle? get currentCycle => _currentCycle;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isOffline = false;
  bool get isOffline => _isOffline;

  /// Optimistically deleted dump IDs to prevent background tasks from resurrecting deleted cards
  final Set<String> _deletedDumpIds = {};

  /// Optimistically deleted task IDs to prevent sync from resurrecting deleted tasks
  final Set<String> _deletedTaskIds = {};

  /// Cache of storage path -> signed URL so cards don't wait on network URL generation on every refresh
  final Map<String, String> _signedUrlCache = {};

  // User Profile State
  String _preferredName = '';
  String get preferredName {
    if (_preferredName.trim().isNotEmpty) return _preferredName.trim();
    final user = SupabaseService().currentUser;
    final metaName = (user?.userMetadata?['preferred_name'] ??
            user?.userMetadata?['full_name'])
        ?.toString()
        .trim();
    if (metaName != null && metaName.isNotEmpty) return metaName;
    final emailPrefix = user?.email?.split('@').first;
    return (emailPrefix != null && emailPrefix.isNotEmpty)
        ? emailPrefix
        : 'Friend';
  }

  String _profession = '';
  String get profession => _profession;

  DateTime? _dob;
  DateTime? get dob => _dob;

  String? _avatarLocalPath;
  String? get avatarLocalPath => _avatarLocalPath;

  String? _avatarUrl;
  String? get avatarUrl => _avatarUrl;

  int _ritualHour = 21;
  int _ritualMinute = 0;
  int get ritualHour => _ritualHour;
  int get ritualMinute => _ritualMinute;

  List<ReflectionRitual> _rituals = [];
  List<ReflectionRitual> get rituals => List.unmodifiable(_rituals);

  ReflectionRitual? get nextUpcomingRitual {
    if (_rituals.isEmpty) return null;
    final enabled = _rituals.where((r) => r.isEnabled).toList();
    if (enabled.isEmpty) return null;
    final now = DateTime.now();
    enabled.sort((a, b) {
      final aTime = DateTime(now.year, now.month, now.day, a.hour, a.minute);
      final bTime = DateTime(now.year, now.month, now.day, b.hour, b.minute);
      final aTarget = aTime.isBefore(now) ? aTime.add(Duration(days: a.cadenceDays)) : aTime;
      final bTarget = bTime.isBefore(now) ? bTime.add(Duration(days: b.cadenceDays)) : bTime;
      return aTarget.compareTo(bTarget);
    });
    return enabled.first;
  }

  String get ritualTimeFormatted {
    if (isPro && _rituals.isNotEmpty) {
      final next = nextUpcomingRitual;
      if (next != null) {
        return next.timeFormatted;
      }
    }
    final hour = _ritualHour > 12
        ? _ritualHour - 12
        : (_ritualHour == 0 ? 12 : _ritualHour);
    final amPm = _ritualHour >= 12 ? 'PM' : 'AM';
    final min = _ritualMinute.toString().padLeft(2, '0');
    return '$hour:$min $amPm';
  }

  Future<void> updateRitualTime(int hour, int minute) async {
    _ritualHour = hour;
    _ritualMinute = minute;
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = SupabaseService().currentUser?.id;
      if (uid != null && uid.isNotEmpty) {
        await prefs.setInt('reflection_reminder_hour_$uid', hour);
        await prefs.setInt('reflection_reminder_minute_$uid', minute);
      }
      await prefs.setInt('schedule_hour', hour);
      await prefs.setInt('schedule_minute', minute);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> loadRituals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = SupabaseService().currentUser;
      final uid = user?.id;
      final suffix = (uid != null && uid.isNotEmpty) ? '_$uid' : '';
      final raw = prefs.getString('multi_reflection_rituals$suffix');
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw);
        _rituals = decoded
            .map((e) => ReflectionRitual.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } else {
        final metaRituals = user?.userMetadata?['multi_rituals'];
        if (metaRituals is List && metaRituals.isNotEmpty) {
          _rituals = metaRituals
              .map((e) => ReflectionRitual.fromMap(Map<String, dynamic>.from(e)))
              .toList();
        } else {
          _rituals = ReflectionRitual.defaultRituals(
            eveningHour: _ritualHour,
            eveningMinute: _ritualMinute,
          );
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading rituals in AppState: $e');
    }
  }

  Future<void> updateRituals(List<ReflectionRitual> newRituals) async {
    _rituals = List.from(newRituals);
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = SupabaseService().currentUser;
      final uid = user?.id;
      final suffix = (uid != null && uid.isNotEmpty) ? '_$uid' : '';
      final encoded = jsonEncode(_rituals.map((r) => r.toJson()).toList());
      await prefs.setString('multi_reflection_rituals$suffix', encoded);

      final eveningRitual = _rituals.firstWhereOrNull((r) => r.id == 'dusk') ??
          _rituals.firstWhereOrNull((r) => r.hour >= 18) ??
          _rituals.firstOrNull;
      if (eveningRitual != null) {
        _ritualHour = eveningRitual.hour;
        _ritualMinute = eveningRitual.minute;
        if (uid != null && uid.isNotEmpty) {
          await prefs.setInt('reflection_reminder_hour_$uid', _ritualHour);
          await prefs.setInt('reflection_reminder_minute_$uid', _ritualMinute);
        }
        await prefs.setInt('schedule_hour', _ritualHour);
        await prefs.setInt('schedule_minute', _ritualMinute);
      }

      unawaited(SupabaseService().updateUserScheduleSettings(
        reminderHour: _ritualHour,
        reminderMinute: _ritualMinute,
        multiRituals: _rituals.map((r) => r.toMap()).toList(),
      ));

      unawaited(NotificationService().scheduleMultiRitualReminders(_rituals));
    } catch (e) {
      debugPrint('Error saving rituals in AppState: $e');
    }
    notifyListeners();
  }

  Future<void> fetchAllDumps() => fetchCurrentCycle();

  AppState() {
    _setupListeners();
    _init();
  }

  void _setupListeners() {
    _activeUserId = SupabaseService().currentUser?.id;

    CaptureService.getAvailableTags = () => availableTags;

    // 1. Listen for real-time AI Title, Summary, Transcript & Sync status updates
    CaptureService.onDumpUpdated = (dumpId, updatedFields) {
      if (updatedFields['tags'] != null) {
        unawaited(addCustomTags(Dump.parseTags(updatedFields['tags'])));
      }
      updateDumpInList(dumpId, updatedFields);
    };

    CaptureService.onDumpAiGenerated = (dumpId, title, summary) {
      updateDumpInList(dumpId, {
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
        if (title != null && title.trim().isNotEmpty) 'category': title.trim(),
        if (summary != null && summary.trim().isNotEmpty) 'ai_summary': summary.trim(),
      });
    };

    TaskService.onTasksChanged = () {
      unawaited(loadTasksFromLocalDb());
    };

    TaskService.onNewTagsDiscovered = (tags) {
      unawaited(addCustomTags(tags));
    };

    // 2. Listen for Supabase auth session changes (sign-in, sign-up, sign-out, user switch)
    try {
      _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        final event = data.event;
        final sessionUser = data.session?.user;
        if (event == AuthChangeEvent.signedOut || sessionUser == null) {
          if (_activeUserId != null || _todayDumps.isNotEmpty || _preferredName.isNotEmpty) {
            unawaited(resetStateForSignOut());
          }
        } else if (sessionUser.id != _activeUserId) {
          unawaited(onAuthSessionChanged());
        }
      });
    } catch (_) {}

    // 3. Check initial connectivity and listen for changes
    Connectivity().checkConnectivity().then((results) {
      final isConnected = results.any((r) => r != ConnectivityResult.none);
      if (_isOffline != !isConnected) {
        _isOffline = !isConnected;
        notifyListeners();
      }
    });

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) async {
      final isConnected = results.any((r) => r != ConnectivityResult.none);
      _isOffline = !isConnected;
      notifyListeners();
      if (isConnected && SupabaseService().currentUser != null) {
        debugPrint('Network connection active. Triggering instant offline sync...');
        await CaptureService().syncPendingDumps();
        await fetchCurrentCycle();
      }
    });

    // 4. Listen for Pro subscription state changes from RevenueCat
    _subscription.isProNotifier.addListener(() {
      notifyListeners();
      if (_subscription.isPro && SupabaseService().currentUser != null) {
        unawaited(_syncInBackground());
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  void _clearInMemoryUserState() {
    _pendingDumps = [];
    _todayDumps = [];
    _projects = [];
    _activeProjectId = null;
    _tasks = [];
    _customTags = [];
    _currentCycle = null;
    _preferredName = '';
    _profession = '';
    _dob = null;
    _avatarLocalPath = null;
    _avatarUrl = null;
    _deletedDumpIds.clear();
    _deletedTaskIds.clear();
    _signedUrlCache.clear();
    CaptureService().clearState();
  }

  /// Clears all in-memory user data when signing out so nothing leaks to the next user.
  Future<void> resetStateForSignOut() async {
    _activeUserId = null;
    _clearInMemoryUserState();
    await _subscription.linkUserId(null);
    notifyListeners();
  }

  /// Resets in-memory state and reloads profile + local/cloud dumps for the newly authenticated user.
  Future<void> onAuthSessionChanged() async {
    final user = SupabaseService().currentUser;
    if (user == null) {
      await resetStateForSignOut();
      return;
    }

    _activeUserId = user.id;
    _clearInMemoryUserState();
    notifyListeners();

    try {
      // Migrate guest 'local_user' data to this authenticated user account
      await _localDb.migrateLocalDataToUser(user.id);
      await _subscription.linkUserId(user.id);

      await Future.wait([
        loadUserProfile(),
        loadProjects(),
        loadDumpsFromLocalDb(),
        loadTasksFromLocalDb(),
      ]);
    } catch (e) {
      debugPrint('Error loading user state on auth change: $e');
    }

    // Re-schedule the user's reflection alarm using their saved cadence & time
    unawaited(NotificationService().scheduleNextCadenceReminder());
    if (isPro) {
      unawaited(_syncInBackground());
    }
  }

  Future<void> _init() async {
    try {
      _activeUserId = SupabaseService().currentUser?.id;
      await _subscription.initialize(userId: _activeUserId);
      // 1. Instantly load from Local DB & local preferences first so UI renders with 0 network wait
      await Future.wait([
        loadUserProfile(),
        loadProjects(),
        loadDumpsFromLocalDb(),
        loadTasksFromLocalDb(),
      ]);
    } catch (e) {
      debugPrint('Error loading local state: $e');
    }

    _isLoading = false;
    notifyListeners();

    // 2. Sync with cloud only if user is logged in AND has Pro subscription
    if (isPro && SupabaseService().currentUser != null) {
      unawaited(_syncInBackground());
    }
  }

  Future<void> _syncInBackground() async {
    if (!isPro || SupabaseService().currentUser == null) return;
    try {
      await fetchCurrentCycle();
      await CaptureService().syncPendingDumps();
      await syncTasks();
    } catch (e) {
      debugPrint('Error in background sync: $e');
    }
  }

  String _profileKey(String baseKey, [String? uidOverride]) {
    final uid = uidOverride ?? SupabaseService().currentUser?.id;
    if (uid == null || uid.isEmpty) return '';
    return '${baseKey}_$uid';
  }

  /// Removes legacy un-scoped global profile keys so they never leak across accounts.
  Future<void> _purgeLegacyGlobalProfileKeys(SharedPreferences prefs) async {
    const legacyKeys = [
      'profile_preferred_name',
      'profile_profession',
      'profile_dob',
      'profile_avatar_local',
      'profile_avatar_url',
    ];
    for (final key in legacyKeys) {
      if (prefs.containsKey(key)) {
        await prefs.remove(key);
      }
    }
  }

  /// Updates the active app color theme immediately and persists it to app preferences.
  Future<void> setColorTheme(AppColorThemeId theme) async {
    if (_colorTheme == theme && AppTheme.activeThemeId == theme) return;
    _colorTheme = theme;
    AppTheme.setActiveTheme(theme);
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: theme.palette.background,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(colorThemePrefKey, theme.id);
      final uid = SupabaseService().currentUser?.id;
      if (uid != null && uid.isNotEmpty) {
        await prefs.setString('${colorThemePrefKey}_$uid', theme.id);
      }
    } catch (e) {
      debugPrint('Error saving color theme preference: $e');
    }
  }

  /// Loads user profile & schedule details strictly scoped to the current user's ID,
  /// hydrating local SharedPreferences from Supabase userMetadata when signing in.
  Future<void> loadUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _purgeLegacyGlobalProfileKeys(prefs);

      // Load saved color theme from preferences (user-scoped or global fallback)
      final user = SupabaseService().currentUser;
      final uid = user?.id;
      final savedThemeStr = (uid != null && uid.isNotEmpty)
          ? (prefs.getString('${colorThemePrefKey}_$uid') ??
              prefs.getString(colorThemePrefKey))
          : prefs.getString(colorThemePrefKey);
      if (savedThemeStr != null && savedThemeStr.isNotEmpty) {
        _colorTheme = AppColorThemeId.fromId(savedThemeStr);
        AppTheme.setActiveTheme(_colorTheme);
      }

      if (user == null) {
        _preferredName = '';
        _profession = '';
        _dob = null;
        _avatarLocalPath = null;
        _avatarUrl = null;
        notifyListeners();
        return;
      }

      final meta = user.userMetadata ?? {};

      final localName = prefs.getString(_profileKey('profile_preferred_name', uid));
      final metaName =
          (meta['preferred_name'] ?? meta['full_name'])?.toString();
      _preferredName = (localName != null && localName.trim().isNotEmpty)
          ? localName.trim()
          : (metaName?.trim() ?? '');
      if ((localName == null || localName.isEmpty) && _preferredName.isNotEmpty) {
        await prefs.setString(_profileKey('profile_preferred_name', uid), _preferredName);
      }

      final localProf = prefs.getString(_profileKey('profile_profession', uid));
      final metaProf = meta['profession']?.toString();
      _profession = (localProf ?? metaProf ?? '').trim();
      if ((localProf == null || localProf.isEmpty) && _profession.isNotEmpty) {
        await prefs.setString(_profileKey('profile_profession', uid), _profession);
      }

      final localDobStr = prefs.getString(_profileKey('profile_dob', uid)) ??
          meta['dob']?.toString();
      if (localDobStr != null && localDobStr.isNotEmpty) {
        _dob = DateTime.tryParse(localDobStr);
        if (!prefs.containsKey(_profileKey('profile_dob', uid))) {
          await prefs.setString(_profileKey('profile_dob', uid), localDobStr);
        }
      } else {
        _dob = null;
      }

      final localAvatar = prefs.getString(_profileKey('profile_avatar_local', uid));
      if (localAvatar != null &&
          localAvatar.isNotEmpty &&
          File(localAvatar).existsSync()) {
        _avatarLocalPath = localAvatar;
      } else {
        _avatarLocalPath = null;
      }

      _avatarUrl = (prefs.getString(_profileKey('profile_avatar_url', uid)) ??
              meta['avatar_url'])
          ?.toString();
      if (_avatarUrl != null &&
          _avatarUrl!.isNotEmpty &&
          !prefs.containsKey(_profileKey('profile_avatar_url', uid))) {
        await prefs.setString(_profileKey('profile_avatar_url', uid), _avatarUrl!);
      }

      // Hydrate user-scoped schedule & alarm settings from Supabase userMetadata if not cached locally
      final metaCadence = meta['reflection_cadence_days'];
      if (metaCadence is int && !prefs.containsKey('reflection_cadence_days_$uid')) {
        await prefs.setInt('reflection_cadence_days_$uid', metaCadence);
      }
      final metaHour = meta['reflection_reminder_hour'];
      if (metaHour is int && !prefs.containsKey('reflection_reminder_hour_$uid')) {
        await prefs.setInt('reflection_reminder_hour_$uid', metaHour);
      }
      final metaMinute = meta['reflection_reminder_minute'];
      if (metaMinute is int && !prefs.containsKey('reflection_reminder_minute_$uid')) {
        await prefs.setInt('reflection_reminder_minute_$uid', metaMinute);
      }
      _ritualHour = prefs.getInt('reflection_reminder_hour_$uid') ??
          prefs.getInt('schedule_hour') ??
          (metaHour is int ? metaHour : null) ??
          21;
      _ritualMinute = prefs.getInt('reflection_reminder_minute_$uid') ??
          prefs.getInt('schedule_minute') ??
          (metaMinute is int ? metaMinute : null) ??
          0;
      final metaAlarm = meta['selected_alarm_sound_id']?.toString();
      if (metaAlarm != null &&
          metaAlarm.isNotEmpty &&
          !prefs.containsKey('selected_alarm_sound_id_$uid')) {
        await prefs.setString('selected_alarm_sound_id_$uid', metaAlarm);
      }

      await loadRituals();

      // Hydrate user-scoped custom tags from SharedPreferences and Supabase userMetadata
      final localCustomTags =
          prefs.getStringList(_profileKey('custom_tags', uid)) ?? const [];
      final metaCustomTags = Dump.parseTags(meta['custom_tags']);
      final defaultLower = Dump.defaultTags.map((t) => t.toLowerCase()).toSet();
      _customTags = Dump.parseTags([...localCustomTags, ...metaCustomTags])
          .where((t) => !defaultLower.contains(t.toLowerCase()))
          .toList();
      if (_customTags.isNotEmpty) {
        await prefs.setStringList(_profileKey('custom_tags', uid), _customTags);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  /// Adds a single custom tag to the user's tag list and returns the normalized tag.
  Future<String?> addCustomTag(String rawTag) async {
    final norm = Dump.normalizeTag(rawTag);
    if (norm.isEmpty) return null;

    final existingMatch = availableTags.firstWhere(
      (t) => t.toLowerCase() == norm.toLowerCase(),
      orElse: () => '',
    );
    if (existingMatch.isNotEmpty) return existingMatch;

    await addCustomTags([norm]);
    return norm;
  }

  /// Adds any non-default tags to the user's persisted custom tags list.
  Future<void> addCustomTags(List<String> rawTags) async {
    final normalized = Dump.parseTags(rawTags);
    if (normalized.isEmpty) return;

    final defaultLower = Dump.defaultTags.map((t) => t.toLowerCase()).toSet();
    final existingCustomLower = _customTags.map((t) => t.toLowerCase()).toSet();

    bool changed = false;
    final updated = List<String>.from(_customTags);
    for (final tag in normalized) {
      final lower = tag.toLowerCase();
      if (!defaultLower.contains(lower) && existingCustomLower.add(lower)) {
        updated.add(tag);
        changed = true;
      }
    }

    if (!changed) return;
    _customTags = updated;
    notifyListeners();

    try {
      final uid = SupabaseService().currentUser?.id;
      if (uid != null && uid.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(_profileKey('custom_tags', uid), _customTags);
        unawaited(SupabaseService().updateUserCustomTags(_customTags));
      }
    } catch (e) {
      debugPrint('Error saving custom tags: $e');
    }
  }

  /// Updates the tags for a specific dump locally and in Supabase.
  Future<void> updateDumpTags(String dumpId, List<String> tags) async {
    if (_deletedDumpIds.contains(dumpId)) return;
    final normalized = Dump.parseTags(tags);
    if (normalized.isNotEmpty) {
      unawaited(addCustomTags(normalized));
    }
    updateDumpInList(dumpId, {'tags': normalized});
    await _localDb.updateDumpTags(dumpId, normalized);
    unawaited(SupabaseService().updateDumpTags(dumpId, normalized));
  }

  /// Updates user profile locally (scoped by user ID) and syncs with Supabase Auth & Storage.
  Future<void> saveUserProfile({
    required String preferredName,
    String? profession,
    DateTime? dob,
    File? newAvatarFile,
    bool clearDob = false,
    bool clearAvatar = false,
  }) async {
    final user = SupabaseService().currentUser;
    if (user == null) return;
    final uid = user.id;

    final trimmedName = preferredName.trim();
    final trimmedProfession = (profession ?? '').trim();

    _preferredName = trimmedName;
    _profession = trimmedProfession;
    if (clearDob) {
      _dob = null;
    } else if (dob != null) {
      _dob = dob;
    }

    final prefs = await SharedPreferences.getInstance();
    await _purgeLegacyGlobalProfileKeys(prefs);
    await prefs.setString(_profileKey('profile_preferred_name', uid), trimmedName);
    await prefs.setString(_profileKey('profile_profession', uid), trimmedProfession);
    await prefs.setBool(_profileKey('profile_setup_completed', uid), true);

    if (clearDob) {
      await prefs.remove(_profileKey('profile_dob', uid));
    } else if (_dob != null) {
      final dobIso = _dob!.toIso8601String().split('T').first;
      await prefs.setString(_profileKey('profile_dob', uid), dobIso);
    }

    if (clearAvatar) {
      _avatarLocalPath = null;
      _avatarUrl = null;
      await prefs.remove(_profileKey('profile_avatar_local', uid));
      await prefs.remove(_profileKey('profile_avatar_url', uid));
    } else if (newAvatarFile != null && newAvatarFile.existsSync()) {
      try {
        final docsDir = await getApplicationDocumentsDirectory();
        final avatarDir = Directory('${docsDir.path}/profile_avatars');
        if (!await avatarDir.exists()) {
          await avatarDir.create(recursive: true);
        }
        final ext = newAvatarFile.path.split('.').last.toLowerCase();
        final safeExt = (ext == 'png' || ext == 'webp') ? ext : 'jpg';
        final destPath =
            '${avatarDir.path}/avatar_${uid}_${DateTime.now().millisecondsSinceEpoch}.$safeExt';
        final savedFile = await newAvatarFile.copy(destPath);
        _avatarLocalPath = savedFile.path;
        await prefs.setString(
          _profileKey('profile_avatar_local', uid),
          savedFile.path,
        );
      } catch (e) {
        debugPrint('Failed to save local avatar copy: $e');
        _avatarLocalPath = newAvatarFile.path;
      }
    }

    notifyListeners();

    // Sync with Supabase in try/catch so offline usage never fails
    try {
      String? remoteAvatarUrl = _avatarUrl;
      if (newAvatarFile != null && newAvatarFile.existsSync()) {
        try {
          final uploadedUrl =
              await SupabaseService().uploadProfileAvatar(newAvatarFile);
          if (uploadedUrl != null) {
            remoteAvatarUrl = uploadedUrl;
            _avatarUrl = uploadedUrl;
            await prefs.setString(
              _profileKey('profile_avatar_url', uid),
              uploadedUrl,
            );
          }
        } catch (e) {
          debugPrint('Avatar cloud upload deferred/failed: $e');
        }
      }

      await SupabaseService().updateUserProfile(
        preferredName: trimmedName,
        profession: trimmedProfession,
        dob: _dob,
        avatarUrl: remoteAvatarUrl,
        clearDob: clearDob,
        clearAvatar: clearAvatar,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Supabase profile update error (saved locally): $e');
    }
  }

  bool _isLocalFilePresent(String? path) {
    if (path == null || path.isEmpty) return false;
    if (path.startsWith('http://') || path.startsWith('https://')) return false;
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  /// Instantly loads all dumps for the current user from SQLite local DB so cards render immediately without network wait.
  Future<void> loadDumpsFromLocalDb() async {
    try {
      final currentUserId = SupabaseService().currentUser?.id ?? 'local_user';
      final localDumps = await _localDb.getAllDumps(userId: currentUserId);

      final filteredLocal = localDumps.where((d) {
        if (_deletedDumpIds.contains(d.id)) return false;
        return d.userId == currentUserId;
      }).toList();

      _pendingDumps = filteredLocal
          .where((d) => d.syncStatus == SyncStatus.pending)
          .toList();

      final existingById = {
        for (final item in _todayDumps)
          if (item['id'] != null && item['user_id']?.toString() == currentUserId)
            item['id'].toString(): item,
      };

      final List<Map<String, dynamic>> merged = [];
      for (final d in filteredLocal) {
        final map = d.toMap();
        final prev = existingById[d.id];
        if (prev != null) {
          // Keep resolved signed URL in memory if local file does not exist
          if (!_isLocalFilePresent(d.mediaUrl) &&
              prev['media_url'] != null &&
              prev['media_url'].toString().startsWith('http')) {
            map['media_url'] = prev['media_url'];
          }
        }
        map['is_processing'] = CaptureService().isProcessing(d.id);
        merged.add(map);
      }

      // Also keep any in-memory dumps for the current user that were just added optimistically
      final mergedIds = merged.map((m) => m['id'].toString()).toSet();
      for (final prev in _todayDumps) {
        final id = prev['id']?.toString();
        final prevUserId = prev['user_id']?.toString();
        if (id != null &&
            prevUserId == currentUserId &&
            !_deletedDumpIds.contains(id) &&
            !mergedIds.contains(id)) {
          merged.add(prev);
        }
      }

      _sortDumpsNewestFirst(merged);
      _todayDumps = merged;
      _syncHomeWidget();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading dumps from local DB: $e');
    }
  }

  void _syncHomeWidget() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    const weekdayShort = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

    int thoughtCount = 0;
    int voiceCount = 0;
    int photoCount = 0;
    int todayCount = 0;
    int morning = 0, afternoon = 0, evening = 0, night = 0;

    final List<DateTime> parsedDates = [];

    for (final d in _todayDumps) {
      final type = d['type']?.toString().toLowerCase() ?? '';
      if (type == 'text') {
        thoughtCount++;
      } else if (type == 'voice') {
        voiceCount++;
      } else if (type == 'photo') {
        photoCount++;
      }

      final rawDate = d['captured_at'] ?? d['created_at'];
      DateTime? dt;
      if (rawDate is DateTime) {
        dt = rawDate.toLocal();
      } else if (rawDate != null) {
        dt = DateTime.tryParse(rawDate.toString())?.toLocal();
      }

      if (dt != null) {
        parsedDates.add(dt);
        if (dt.year == today.year &&
            dt.month == today.month &&
            dt.day == today.day) {
          todayCount++;
        }
        final h = dt.hour;
        if (h >= 5 && h < 12) {
          morning++;
        } else if (h >= 12 && h < 17) {
          afternoon++;
        } else if (h >= 17 && h < 22) {
          evening++;
        } else {
          night++;
        }
      }
    }

    final List<int> weeklyCounts = [];
    final List<String> weeklyLabels = [];
    int activeDays = 0;

    for (int i = 6; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      int c = 0;
      for (final dt in parsedDates) {
        if (dt.year == day.year &&
            dt.month == day.month &&
            dt.day == day.day) {
          c++;
        }
      }
      if (c > 0) activeDays++;
      weeklyCounts.add(c);
      weeklyLabels.add(weekdayShort[day.weekday - 1]);
    }

    String peakPeriod = 'Evening';
    final buckets = {
      'Morning': morning,
      'Afternoon': afternoon,
      'Evening': evening,
      'Night': night,
    };
    int bestVal = 0;
    buckets.forEach((k, v) {
      if (v > bestVal) {
        bestVal = v;
        peakPeriod = k;
      }
    });

    final totalCaptures = _todayDumps.length;
    final isCompleted = _currentCycle?.status == CycleStatus.completed;
    final int ritualProgress = isCompleted
        ? 100
        : ((totalCaptures / 4.0).clamp(0.0, 1.0) * 100).round();

    QuickCaptureService().updateWidgetData(
      dumpCount: todayCount,
      todayCount: todayCount,
      totalCount: totalCaptures,
      thoughtCount: thoughtCount,
      voiceCount: voiceCount,
      photoCount: photoCount,
      weeklyCounts: weeklyCounts,
      weeklyLabels: weeklyLabels,
      activeDays: activeDays,
      ritualProgress: ritualProgress,
      ritualCompleted: isCompleted,
      peakPeriod: peakPeriod,
    );
  }

  void _sortDumpsNewestFirst(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      final rawA = a['captured_at'] ?? a['created_at'];
      final rawB = b['captured_at'] ?? b['created_at'];
      final dateA = DateTime.tryParse(rawA?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = DateTime.tryParse(rawB?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return dateB.compareTo(dateA);
    });
  }

  Future<void> fetchCurrentCycle() async {
    final currentUserId = SupabaseService().currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) {
      _todayDumps = [];
      _pendingDumps = [];
      _currentCycle = null;
      notifyListeners();
      return;
    }

    // Ensure local DB dumps are already shown immediately before any network call
    if (_todayDumps.isEmpty) {
      await loadDumpsFromLocalDb();
    }

    try {
      final results = await Future.wait<dynamic>([
        SupabaseService().getOrCreateCurrentCycle().catchError((_) => null),
        SupabaseService().getAllDumps().catchError((_) => <Map<String, dynamic>>[]),
      ]);

      // Abort if the active user changed while the network call was in flight
      if (SupabaseService().currentUser?.id != currentUserId) return;

      final cycle = results[0] as ReflectionCycle?;
      if (cycle != null && cycle.userId == currentUserId) {
        _currentCycle = cycle;
      }

      final rawRemoteDumps = (results[1] as List<Map<String, dynamic>>)
          .where((d) =>
              d['id'] != null &&
              d['user_id']?.toString() == currentUserId &&
              !_deletedDumpIds.contains(d['id'].toString()))
          .toList();

      final localDumps = await _localDb.getAllDumps(userId: currentUserId);
      final localById = {for (final d in localDumps) d.id: d};
      final memoryById = {
        for (final d in _todayDumps)
          if (d['id'] != null && d['user_id']?.toString() == currentUserId)
            d['id'].toString(): d,
      };

      // Resolve signed URLs in parallel only for remote dumps that don't have a local file on disk
      await Future.wait(rawRemoteDumps.map((dump) async {
        final id = dump['id'].toString();
        final local = localById[id];
        final inMem = memoryById[id];

        // 1. Prefer local file path if it exists on disk so images/audio load with zero network lag
        final localPath = local?.mediaUrl ?? inMem?['media_url']?.toString();
        String? storagePathForLocalDb;
        if (_isLocalFilePresent(localPath)) {
          dump['media_url'] = localPath;
          storagePathForLocalDb = localPath;
        } else if (dump['media_url'] != null) {
          final remoteMedia = dump['media_url'].toString();
          storagePathForLocalDb = remoteMedia;
          if (!remoteMedia.startsWith('http') && !remoteMedia.startsWith('/')) {
            if (_signedUrlCache.containsKey(remoteMedia)) {
              dump['media_url'] = _signedUrlCache[remoteMedia];
            } else {
              try {
                final signed = await SupabaseService().getSignedUrl(remoteMedia);
                _signedUrlCache[remoteMedia] = signed;
                dump['media_url'] = signed;
              } catch (_) {}
            }
          }
        }

        // 2. Normalize and merge title, category, ai_summary, and transcript
        final rawTitle = dump['title'] ?? dump['category'];
        if (rawTitle != null &&
            rawTitle.toString().trim().isNotEmpty &&
            rawTitle.toString().toLowerCase() != 'null') {
          dump['title'] = rawTitle.toString().trim();
          dump['category'] = rawTitle.toString().trim();
        } else {
          final fallbackTitle = local?.title ?? inMem?['title']?.toString();
          if (fallbackTitle != null && fallbackTitle.trim().isNotEmpty) {
            dump['title'] = fallbackTitle.trim();
            dump['category'] = fallbackTitle.trim();
          }
        }

        if ((dump['ai_summary'] == null || dump['ai_summary'].toString().trim().isEmpty)) {
          final fallbackSummary = local?.aiSummary ?? inMem?['ai_summary']?.toString();
          if (fallbackSummary != null && fallbackSummary.trim().isNotEmpty) {
            dump['ai_summary'] = fallbackSummary.trim();
          }
        }

        if ((dump['transcript'] == null || dump['transcript'].toString().trim().isEmpty)) {
          final fallbackTranscript = local?.transcript ?? inMem?['transcript']?.toString();
          if (fallbackTranscript != null && fallbackTranscript.trim().isNotEmpty) {
            dump['transcript'] = fallbackTranscript.trim();
          }
        }

        final remoteTags = Dump.parseTags(dump['tags']);
        final fallbackTags = local?.tags ?? Dump.parseTags(inMem?['tags']);
        dump['tags'] = remoteTags.isNotEmpty ? remoteTags : fallbackTags;

        final remoteProjectId = dump['project_id']?.toString();
        final fallbackProjectId = local?.projectId ?? inMem?['project_id']?.toString();
        dump['project_id'] = (remoteProjectId != null && remoteProjectId.isNotEmpty)
            ? remoteProjectId
            : fallbackProjectId;

        dump['is_processing'] = CaptureService().isProcessing(id);

        // Cache merged record in Local DB for instant future startups
        final dbRecord = Map<String, dynamic>.from(dump);
        if (storagePathForLocalDb != null) {
          dbRecord['media_url'] = storagePathForLocalDb;
        }
        unawaited(_localDb.upsertMergedDump(dbRecord));
      }));

      if (SupabaseService().currentUser?.id != currentUserId) return;

      final remoteIds = rawRemoteDumps.map((d) => d['id'].toString()).toSet();

      // Keep all local / in-flight dumps for THIS user that aren't in remoteDumps yet (and haven't been deleted)
      final Map<String, Map<String, dynamic>> uniqueLocalMap = {};
      for (final d in localDumps) {
        if (d.userId == currentUserId &&
            !_deletedDumpIds.contains(d.id) &&
            !remoteIds.contains(d.id)) {
          final map = d.toMap();
          map['is_processing'] = CaptureService().isProcessing(d.id);
          uniqueLocalMap[d.id] = map;
        }
      }
      for (final d in _todayDumps) {
        final id = d['id']?.toString();
        final dumpUserId = d['user_id']?.toString();
        if (id != null &&
            dumpUserId == currentUserId &&
            !_deletedDumpIds.contains(id) &&
            !remoteIds.contains(id) &&
            !uniqueLocalMap.containsKey(id)) {
          uniqueLocalMap[id] = d;
        }
      }

      final combined = [...uniqueLocalMap.values, ...rawRemoteDumps]
          .where((d) =>
              d['id'] != null &&
              d['user_id']?.toString() == currentUserId &&
              !_deletedDumpIds.contains(d['id'].toString()))
          .toList();
      _sortDumpsNewestFirst(combined);
      _todayDumps = combined;
      _syncHomeWidget();

      await fetchPendingDumps();
      unawaited(syncTasks());
    } catch (e) {
      debugPrint('Error fetching cycle: $e');
    }
    notifyListeners();
  }

  Future<void> fetchPendingDumps() async {
    final currentUserId = SupabaseService().currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) {
      _pendingDumps = [];
      notifyListeners();
      return;
    }
    final pending = await _localDb.getPendingDumps(userId: currentUserId);
    _pendingDumps = pending
        .where((d) => d.userId == currentUserId && !_deletedDumpIds.contains(d.id))
        .toList();
    notifyListeners();
  }

  void setCurrentCycle(ReflectionCycle cycle) {
    _currentCycle = cycle;
    notifyListeners();
  }

  /// Immediately adds a newly captured dump to the list for 0ms optimistic UI display.
  void addDumpLocally(Dump dump) {
    final currentUserId = SupabaseService().currentUser?.id;
    if (currentUserId == null || dump.userId != currentUserId) return;

    if (dump.tags.isNotEmpty) {
      unawaited(addCustomTags(dump.tags));
    }

    _deletedDumpIds.remove(dump.id);
    final dumpMap = dump.toMap();
    dumpMap['is_processing'] = CaptureService().isProcessing(dump.id);

    _todayDumps.removeWhere((d) => d['id'] == dump.id);
    _todayDumps.insert(0, dumpMap);
    _syncHomeWidget();

    _pendingDumps.removeWhere((d) => d.id == dump.id);
    if (dump.syncStatus == SyncStatus.pending) {
      _pendingDumps.add(dump);
    }
    notifyListeners();
  }

  /// Optimistically deletes a dump in 0ms from UI, removes from local DB,
  /// and deletes from Supabase in the background without blocking.
  void deleteDump(String dumpId) => deleteDumps([dumpId]);

  /// Optimistically deletes multiple dumps in 0ms from UI, removes from local DB,
  /// and deletes from Supabase in the background without blocking.
  void deleteDumps(List<String> dumpIds) {
    if (dumpIds.isEmpty) return;
    final idSet = dumpIds.toSet();
    _deletedDumpIds.addAll(dumpIds);
    for (final id in dumpIds) {
      CaptureService().markDeleted(id);
    }

    _todayDumps.removeWhere((d) => idSet.contains(d['id']));
    _pendingDumps.removeWhere((d) => idSet.contains(d.id));
    _tasks.removeWhere((t) => t.dumpId != null && idSet.contains(t.dumpId));
    _syncHomeWidget();
    notifyListeners();

    unawaited(_performBackgroundDeleteBatch(dumpIds));
  }

  Future<void> _performBackgroundDeleteBatch(List<String> dumpIds) async {
    final userId = SupabaseService().currentUser?.id;
    try {
      await _localDb.deleteDumpsBatch(dumpIds, userId: userId);
    } catch (e) {
      debugPrint('Local DB batch delete error: $e');
    }
    try {
      await SupabaseService().deleteDumps(dumpIds);
    } catch (e) {
      debugPrint('Background cloud batch delete error: $e');
    }
  }

  /// Updates a specific dump in the list immediately (e.g., when transcript/title/summary/sync_status arrives).
  void updateDumpInList(String dumpId, Map<String, dynamic> updatedFields) {
    if (_deletedDumpIds.contains(dumpId)) return;

    if (updatedFields['sync_status'] == SyncStatus.synced.name) {
      _pendingDumps.removeWhere((d) => d.id == dumpId);
    }

    final index = _todayDumps.indexWhere((d) => d['id'] == dumpId);
    if (index != -1) {
      _todayDumps[index] = {..._todayDumps[index], ...updatedFields};
      notifyListeners();
    }
  }

  /// Refreshes a single dump's AI summary, title, tags & transcript from the local database.
  Future<void> refreshDumpAiSummary(String dumpId) async {
    if (_deletedDumpIds.contains(dumpId)) return;
    final currentUserId = SupabaseService().currentUser?.id;
    if (currentUserId == null) return;
    final dump = await _localDb.getDumpById(dumpId, userId: currentUserId);
    if (dump != null && dump.userId == currentUserId) {
      final updates = <String, dynamic>{
        'sync_status': dump.syncStatus.name,
        'is_processing': CaptureService().isProcessing(dumpId),
      };
      if (dump.aiSummary != null && dump.aiSummary!.isNotEmpty) {
        updates['ai_summary'] = dump.aiSummary;
      }
      if (dump.title != null && dump.title!.isNotEmpty) {
        updates['title'] = dump.title;
        updates['category'] = dump.title;
      }
      if (dump.transcript != null && dump.transcript!.isNotEmpty) {
        updates['transcript'] = dump.transcript;
      }
      if (dump.tags.isNotEmpty) {
        updates['tags'] = dump.tags;
      }
      if (dump.projectId != null) {
        updates['project_id'] = dump.projectId;
      }
      updateDumpInList(dumpId, updates);
    }
  }

  // ===========================================================================
  // Projects / Spaces State Management (Offline-First + Supabase Sync)
  // ===========================================================================

  void setActiveProject(String? projectId) {
    if (_activeProjectId == projectId) return;
    _activeProjectId = projectId;
    notifyListeners();
  }

  Future<void> loadProjects() async {
    final currentUserId = SupabaseService().currentUser?.id ?? 'local_user';

    try {
      final local = await _localDb.getAllProjects(userId: currentUserId);
      _projects = local;
      notifyListeners();

      if (!_isOffline && SupabaseService().currentUser != null) {
        final remote = await SupabaseService().getAllProjects();
        if (remote.isNotEmpty) {
          final localMap = {for (final p in local) p.id: p};
          for (final r in remote) {
            localMap[r.id] = r;
            await _localDb.insertProject(r);
          }
          _projects = localMap.values.toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error loading projects: $e');
    }
  }

  Future<Project> createProject({
    required String name,
    String? description,
    String? icon,
    int? colorValue,
  }) async {
    final user = SupabaseService().currentUser;
    final userId = user?.id ?? '';
    final project = Project(
      id: _uuid.v4(),
      userId: userId,
      name: name.trim(),
      description: description?.trim(),
      icon: icon,
      colorValue: colorValue,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );

    _projects.add(project);
    _projects.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    notifyListeners();

    await _localDb.insertProject(project);
    unawaited(SupabaseService().upsertProject(project));
    return project;
  }

  Future<void> updateProject(Project project) async {
    final idx = _projects.indexWhere((p) => p.id == project.id);
    if (idx != -1) {
      _projects[idx] = project;
      notifyListeners();
    }
    await _localDb.updateProject(project);
    unawaited(SupabaseService().upsertProject(project));
  }

  Future<void> deleteProject(String projectId) async {
    _projects.removeWhere((p) => p.id == projectId);
    if (_activeProjectId == projectId) {
      _activeProjectId = null;
    }
    // Unassign in memory dumps and tasks
    for (int i = 0; i < _todayDumps.length; i++) {
      if (_todayDumps[i]['project_id'] == projectId) {
        _todayDumps[i]['project_id'] = null;
      }
    }
    for (int i = 0; i < _tasks.length; i++) {
      if (_tasks[i].projectId == projectId) {
        _tasks[i] = _tasks[i].copyWith(clearProjectId: true);
      }
    }
    notifyListeners();

    final currentUserId = SupabaseService().currentUser?.id;
    await _localDb.deleteProject(projectId, userId: currentUserId);
    unawaited(SupabaseService().deleteProject(projectId));
  }

  Future<void> setDumpProject(String dumpId, String? projectId) async {
    if (_deletedDumpIds.contains(dumpId)) return;
    updateDumpInList(dumpId, {'project_id': projectId});
    await _localDb.updateDumpProject(dumpId, projectId);
    // Also update any memory tasks associated with this dump
    for (int i = 0; i < _tasks.length; i++) {
      if (_tasks[i].dumpId == dumpId) {
        _tasks[i] = _tasks[i].copyWith(projectId: projectId, clearProjectId: projectId == null);
      }
    }
    notifyListeners();
    unawaited(SupabaseService().updateDumpProject(dumpId, projectId));
  }

  Future<void> setTaskProject(String taskId, String? projectId) async {
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx != -1) {
      _tasks[idx] = _tasks[idx].copyWith(projectId: projectId, clearProjectId: projectId == null);
      notifyListeners();
    }
    await _localDb.updateTaskProject(taskId, projectId);
    unawaited(SupabaseService().updateTaskProject(taskId, projectId));
  }

  // ===========================================================================
  // Tasks & Gentle Next Steps State Management (Offline-First + Supabase Sync)
  // ===========================================================================

  Future<void> loadTasksFromLocalDb() async {
    try {
      final currentUserId = SupabaseService().currentUser?.id ?? 'local_user';
      final deleted = await _localDb.getDeletedTaskIds(userId: currentUserId);
      _deletedTaskIds.addAll(deleted);
      final local = await _localDb.getAllTasks(userId: currentUserId);

      // In-memory deduplication and filtering of non-actionable intro tasks
      final dedupedList = <TaskItem>[];
      final duplicatesToDelete = <String>[];

      for (final t in local) {
        if (t.userId != currentUserId ||
            _deletedTaskIds.contains(t.id) ||
            (t.dumpId != null && _deletedDumpIds.contains(t.dumpId)) ||
            TaskService.isNonActionableIntro(t.title)) {
          if (TaskService.isNonActionableIntro(t.title)) {
            duplicatesToDelete.add(t.id);
          }
          continue;
        }

        // Check if an equivalent task for the same dump is already in dedupedList
        final existingMatch = dedupedList.firstWhereOrNull(
          (existing) =>
              existing.dumpId != null &&
              existing.dumpId == t.dumpId &&
              TaskService.areTaskTitlesEquivalent(existing.title, t.title),
        );

        if (existingMatch != null) {
          duplicatesToDelete.add(t.id);
          continue;
        }

        dedupedList.add(t);
      }

      if (duplicatesToDelete.isNotEmpty) {
        unawaited(_localDb.deleteTasksBatch(duplicatesToDelete, userId: currentUserId));
        unawaited(SupabaseService().deleteTasks(duplicatesToDelete));
      }

      _tasks = dedupedList;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading tasks from local DB: $e');
    }
  }

  Future<void> syncTasks() async {
    final currentUserId = SupabaseService().currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) return;
    try {
      final deleted = await _localDb.getDeletedTaskIds(userId: currentUserId);
      _deletedTaskIds.addAll(deleted);
      final synced = await TaskService().syncAndLoadAllTasks(
        userId: currentUserId,
        currentDumps: _todayDumps,
      );
      if (SupabaseService().currentUser?.id != currentUserId) return;

      final dedupedList = <TaskItem>[];
      final duplicatesToDelete = <String>[];

      for (final t in synced) {
        if (t.userId != currentUserId ||
            _deletedTaskIds.contains(t.id) ||
            (t.dumpId != null && _deletedDumpIds.contains(t.dumpId)) ||
            TaskService.isNonActionableIntro(t.title)) {
          if (TaskService.isNonActionableIntro(t.title)) {
            duplicatesToDelete.add(t.id);
          }
          continue;
        }

        final existingMatch = dedupedList.firstWhereOrNull(
          (existing) =>
              existing.dumpId != null &&
              existing.dumpId == t.dumpId &&
              TaskService.areTaskTitlesEquivalent(existing.title, t.title),
        );

        if (existingMatch != null) {
          duplicatesToDelete.add(t.id);
          continue;
        }

        dedupedList.add(t);
      }

      if (duplicatesToDelete.isNotEmpty) {
        unawaited(_localDb.deleteTasksBatch(duplicatesToDelete, userId: currentUserId));
        unawaited(SupabaseService().deleteTasks(duplicatesToDelete));
      }

      _tasks = dedupedList;
      notifyListeners();
    } catch (e) {
      debugPrint('Error syncing tasks: $e');
    }
  }

  Future<TaskItem?> addManualTask(
    String title, {
    TaskSourceType sourceType = TaskSourceType.manual,
    String? dumpId,
    String? insightCardId,
    String? projectId,
    String? sourceLabel,
    DateTime? dueDate,
    List<String> tags = const [],
  }) async {
    final currentUserId = SupabaseService().currentUser?.id;
    final cleanTitle = title.trim();
    if (currentUserId == null || cleanTitle.isEmpty) return null;

    // Prevent duplicate if adding an Insight Card or Dump task that already exists
    if (insightCardId != null && insightCardId.isNotEmpty) {
      final existingIdx =
          _tasks.indexWhere((t) => t.insightCardId == insightCardId);
      if (existingIdx != -1) return _tasks[existingIdx];
    }

    final resolvedTags = tags.isNotEmpty
        ? Dump.parseTags(tags)
        : (sourceType == TaskSourceType.insight
            ? TaskService.inferTagsForText(
                cleanTitle,
                seedTags: const ['Goals'],
                availableTags: availableTags,
              )
            : const <String>[]);

    if (resolvedTags.isNotEmpty) {
      unawaited(addCustomTags(resolvedTags));
    }

    final now = DateTime.now();
    final task = TaskItem(
      id: _uuid.v4(),
      userId: currentUserId,
      dumpId: dumpId,
      insightCardId: insightCardId,
      projectId: projectId ?? _activeProjectId,
      title: cleanTitle,
      sourceType: sourceType,
      sourceLabel: sourceLabel,
      tags: resolvedTags,
      status: TaskStatus.pending,
      dueDate: dueDate,
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.pending,
    );

    _tasks = [task, ..._tasks];
    notifyListeners();

    await _localDb.insertTask(task);
    unawaited(_syncSingleTaskToRemote(task));
    return task;
  }

  Future<void> updateTask(
    String taskId, {
    String? title,
    DateTime? dueDate,
    bool clearDueDate = false,
    List<String>? tags,
  }) async {
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx == -1) return;

    final current = _tasks[idx];
    final now = DateTime.now();
    final cleanTitle =
        (title != null && title.trim().isNotEmpty) ? title.trim() : current.title;
    final normalizedTags = tags != null ? Dump.parseTags(tags) : null;

    if (normalizedTags != null && normalizedTags.isNotEmpty) {
      unawaited(addCustomTags(normalizedTags));
    }

    final updated = current.copyWith(
      title: cleanTitle,
      dueDate: dueDate,
      clearDueDate: clearDueDate,
      tags: normalizedTags,
      updatedAt: now,
      syncStatus: SyncStatus.pending,
    );

    _tasks[idx] = updated;
    notifyListeners();

    await _localDb.updateTaskDetails(
      taskId,
      title: cleanTitle,
      dueDate: dueDate,
      clearDueDate: clearDueDate,
      tags: normalizedTags,
      syncStatus: SyncStatus.pending,
    );
    unawaited(_syncSingleTaskToRemote(updated));
  }

  Future<void> toggleTaskDone(String taskId) async {
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx == -1) return;

    final current = _tasks[idx];
    final now = DateTime.now();
    final nextStatus =
        current.isDone ? TaskStatus.pending : TaskStatus.done;
    final updated = current.copyWith(
      status: nextStatus,
      completedAt: nextStatus == TaskStatus.done ? now : null,
      clearCompletedAt: nextStatus != TaskStatus.done,
      updatedAt: now,
      syncStatus: SyncStatus.pending,
    );

    _tasks[idx] = updated;
    notifyListeners();

    await _localDb.updateTaskStatus(
      taskId,
      nextStatus,
      completedAt: updated.completedAt,
      clearCompletedAt: nextStatus != TaskStatus.done,
      syncStatus: SyncStatus.pending,
    );
    unawaited(_syncSingleTaskToRemote(updated));
  }

  Future<void> archiveTask(String taskId) async {
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx == -1) return;

    final current = _tasks[idx];
    final now = DateTime.now();
    final updated = current.copyWith(
      status: TaskStatus.archived,
      updatedAt: now,
      syncStatus: SyncStatus.pending,
    );

    _tasks[idx] = updated;
    notifyListeners();

    await _localDb.updateTaskStatus(
      taskId,
      TaskStatus.archived,
      syncStatus: SyncStatus.pending,
    );
    unawaited(_syncSingleTaskToRemote(updated));
  }

  Future<void> unarchiveTask(String taskId) async {
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx == -1) return;

    final current = _tasks[idx];
    final now = DateTime.now();
    final updated = current.copyWith(
      status: TaskStatus.pending,
      clearCompletedAt: true,
      updatedAt: now,
      syncStatus: SyncStatus.pending,
    );

    _tasks[idx] = updated;
    notifyListeners();

    await _localDb.updateTaskStatus(
      taskId,
      TaskStatus.pending,
      clearCompletedAt: true,
      syncStatus: SyncStatus.pending,
    );
    unawaited(_syncSingleTaskToRemote(updated));
  }

  Future<void> deleteTask(String taskId) => deleteTasks([taskId]);

  Future<void> deleteTasks(List<String> taskIds) async {
    if (taskIds.isEmpty) return;
    final currentUserId = SupabaseService().currentUser?.id;
    _deletedTaskIds.addAll(taskIds);
    final idSet = taskIds.toSet();
    final tasksToDelete = _tasks.where((t) => idSet.contains(t.id)).toList();
    _tasks.removeWhere((t) => idSet.contains(t.id));
    notifyListeners();

    if (tasksToDelete.isNotEmpty) {
      await _localDb.recordDeletedTasks(tasksToDelete, userId: currentUserId);
    }
    await _localDb.deleteTasksBatch(taskIds, userId: currentUserId);
    unawaited(SupabaseService().deleteTasks(taskIds));
  }

  Future<void> _syncSingleTaskToRemote(TaskItem task) async {
    final ok = await SupabaseService().upsertTask(task);
    if (ok) {
      await _localDb.updateTaskSyncStatus(task.id, SyncStatus.synced);
      final idx = _tasks.indexWhere((t) => t.id == task.id);
      if (idx != -1) {
        _tasks[idx] = _tasks[idx].copyWith(syncStatus: SyncStatus.synced);
        notifyListeners();
      }
    }
  }
}
