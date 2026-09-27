import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/dump.dart';
import '../models/reflection_cycle.dart';
import '../models/task_item.dart';
import '../services/local_db_service.dart';
import '../services/supabase_service.dart';
import '../services/capture_service.dart';
import '../services/notification_service.dart';
import '../services/quick_capture_service.dart';
import '../services/task_service.dart';

class AppState extends ChangeNotifier {
  final LocalDbService _localDb = LocalDbService();
  final Uuid _uuid = const Uuid();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<AuthState>? _authSubscription;
  String? _activeUserId;

  List<Dump> _pendingDumps = [];
  List<Dump> get pendingDumps => _pendingDumps;

  List<Map<String, dynamic>> _todayDumps = [];
  List<Map<String, dynamic>> get todayDumps => _todayDumps;
  List<Map<String, dynamic>> get allDumps => _todayDumps;

  List<TaskItem> _tasks = [];
  List<TaskItem> get tasks => _tasks;
  int get pendingTasksCount => _tasks.where((t) => t.isPending).length;

  ReflectionCycle? _currentCycle;
  ReflectionCycle? get currentCycle => _currentCycle;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isOffline = false;
  bool get isOffline => _isOffline;

  /// Optimistically deleted dump IDs to prevent background tasks from resurrecting deleted cards
  final Set<String> _deletedDumpIds = {};

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

  Future<void> fetchAllDumps() => fetchCurrentCycle();

  AppState() {
    _setupListeners();
    _init();
  }

  void _setupListeners() {
    _activeUserId = SupabaseService().currentUser?.id;

    // 1. Listen for real-time AI Title, Summary, Transcript & Sync status updates
    CaptureService.onDumpUpdated = (dumpId, updatedFields) {
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

    // 2. Listen for Supabase auth session changes (sign-in, sign-up, sign-out, user switch)
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
    _tasks = [];
    _currentCycle = null;
    _preferredName = '';
    _profession = '';
    _dob = null;
    _avatarLocalPath = null;
    _avatarUrl = null;
    _deletedDumpIds.clear();
    _signedUrlCache.clear();
    CaptureService().clearState();
  }

  /// Clears all in-memory user data when signing out so nothing leaks to the next user.
  Future<void> resetStateForSignOut() async {
    _activeUserId = null;
    _clearInMemoryUserState();
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
      await Future.wait([
        loadUserProfile(),
        loadDumpsFromLocalDb(),
        loadTasksFromLocalDb(),
      ]);
    } catch (e) {
      debugPrint('Error loading user state on auth change: $e');
    }

    // Re-schedule the user's reflection alarm using their saved cadence & time
    unawaited(NotificationService().scheduleNextCadenceReminder());
    unawaited(_syncInBackground());
  }

  Future<void> _init() async {
    try {
      _activeUserId = SupabaseService().currentUser?.id;
      // 1. Instantly load from Local DB & local preferences first so UI renders with 0 network wait
      await Future.wait([
        loadUserProfile(),
        loadDumpsFromLocalDb(),
        loadTasksFromLocalDb(),
      ]);
    } catch (e) {
      debugPrint('Error loading local state: $e');
    }

    _isLoading = false;
    notifyListeners();

    // 2. Sync with cloud and process any pending items in the background without blocking UI
    if (SupabaseService().currentUser != null) {
      unawaited(_syncInBackground());
    }
  }

  Future<void> _syncInBackground() async {
    if (SupabaseService().currentUser == null) return;
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

  /// Loads user profile & schedule details strictly scoped to the current user's ID,
  /// hydrating local SharedPreferences from Supabase userMetadata when signing in.
  Future<void> loadUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _purgeLegacyGlobalProfileKeys(prefs);

      final user = SupabaseService().currentUser;
      if (user == null) {
        _preferredName = '';
        _profession = '';
        _dob = null;
        _avatarLocalPath = null;
        _avatarUrl = null;
        notifyListeners();
        return;
      }

      final uid = user.id;
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
      final metaAlarm = meta['selected_alarm_sound_id']?.toString();
      if (metaAlarm != null &&
          metaAlarm.isNotEmpty &&
          !prefs.containsKey('selected_alarm_sound_id_$uid')) {
        await prefs.setString('selected_alarm_sound_id_$uid', metaAlarm);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
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
      final currentUserId = SupabaseService().currentUser?.id;
      if (currentUserId == null || currentUserId.isEmpty) {
        _pendingDumps = [];
        _todayDumps = [];
        notifyListeners();
        return;
      }

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
    QuickCaptureService().updateWidgetData(dumpCount: _todayDumps.length);
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
  void deleteDump(String dumpId) {
    _deletedDumpIds.add(dumpId);
    CaptureService().markDeleted(dumpId);

    _todayDumps.removeWhere((d) => d['id'] == dumpId);
    _pendingDumps.removeWhere((d) => d.id == dumpId);
    _tasks.removeWhere((t) => t.dumpId == dumpId);
    _syncHomeWidget();
    notifyListeners();

    // Perform local DB and remote Supabase deletion in the background
    unawaited(_performBackgroundDelete(dumpId));
  }

  Future<void> _performBackgroundDelete(String dumpId) async {
    final userId = SupabaseService().currentUser?.id;
    try {
      await _localDb.deleteDump(dumpId, userId: userId);
    } catch (e) {
      debugPrint('Local DB delete error for $dumpId: $e');
    }
    try {
      await SupabaseService().deleteDump(dumpId);
    } catch (e) {
      debugPrint('Background cloud delete error for $dumpId: $e');
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

  /// Refreshes a single dump's AI summary, title & transcript from the local database.
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
      updateDumpInList(dumpId, updates);
    }
  }

  // ===========================================================================
  // Tasks & Gentle Next Steps State Management (Offline-First + Supabase Sync)
  // ===========================================================================

  Future<void> loadTasksFromLocalDb() async {
    try {
      final currentUserId = SupabaseService().currentUser?.id;
      if (currentUserId == null || currentUserId.isEmpty) {
        _tasks = [];
        notifyListeners();
        return;
      }
      final local = await _localDb.getAllTasks(userId: currentUserId);
      _tasks = local
          .where((t) =>
              t.userId == currentUserId &&
              (t.dumpId == null || !_deletedDumpIds.contains(t.dumpId)))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading tasks from local DB: $e');
    }
  }

  Future<void> syncTasks() async {
    final currentUserId = SupabaseService().currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) return;
    try {
      final synced = await TaskService().syncAndLoadAllTasks(
        userId: currentUserId,
        currentDumps: _todayDumps,
      );
      if (SupabaseService().currentUser?.id != currentUserId) return;
      _tasks = synced
          .where((t) =>
              t.userId == currentUserId &&
              (t.dumpId == null || !_deletedDumpIds.contains(t.dumpId)))
          .toList();
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
    String? sourceLabel,
    DateTime? dueDate,
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

    final now = DateTime.now();
    final task = TaskItem(
      id: _uuid.v4(),
      userId: currentUserId,
      dumpId: dumpId,
      insightCardId: insightCardId,
      title: cleanTitle,
      sourceType: sourceType,
      sourceLabel: sourceLabel,
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
  }) async {
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx == -1) return;

    final current = _tasks[idx];
    final now = DateTime.now();
    final cleanTitle =
        (title != null && title.trim().isNotEmpty) ? title.trim() : current.title;

    final updated = current.copyWith(
      title: cleanTitle,
      dueDate: dueDate,
      clearDueDate: clearDueDate,
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

  Future<void> deleteTask(String taskId) async {
    final currentUserId = SupabaseService().currentUser?.id;
    _tasks.removeWhere((t) => t.id == taskId);
    notifyListeners();

    await _localDb.deleteTask(taskId, userId: currentUserId);
    unawaited(SupabaseService().deleteTask(taskId));
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
