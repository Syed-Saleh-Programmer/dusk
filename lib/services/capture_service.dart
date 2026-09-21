import 'package:uuid/uuid.dart';
import '../models/dump.dart';
import 'local_db_service.dart';
import 'supabase_service.dart';

class CaptureService {
  final LocalDbService _localDb = LocalDbService();
  final SupabaseService _supabase = SupabaseService();
  final Uuid _uuid = const Uuid();

  Future<void> captureText(String content) async {
    final userId = _supabase.currentUser?.id ?? 'local_user';
    
    final dump = Dump(
      id: _uuid.v4(),
      userId: userId,
      type: DumpType.text,
      content: content,
      capturedAt: DateTime.now(),
      createdAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );

    await _localDb.insertDump(dump);
    _triggerSync();
  }

  Future<void> captureVoice(String mediaUrl, String transcript) async {
    final userId = _supabase.currentUser?.id ?? 'local_user';
    
    final dump = Dump(
      id: _uuid.v4(),
      userId: userId,
      type: DumpType.voice,
      mediaUrl: mediaUrl,
      transcript: transcript,
      capturedAt: DateTime.now(),
      createdAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );

    await _localDb.insertDump(dump);
    _triggerSync();
  }
  
  Future<void> capturePhoto(String mediaUrl) async {
    final userId = _supabase.currentUser?.id ?? 'local_user';
    
    final dump = Dump(
      id: _uuid.v4(),
      userId: userId,
      type: DumpType.photo,
      mediaUrl: mediaUrl,
      capturedAt: DateTime.now(),
      createdAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );

    await _localDb.insertDump(dump);
    _triggerSync();
  }

  Future<void> _triggerSync() async {
    // In a real app, you would check for network connectivity here before syncing
    try {
      final pendingDumps = await _localDb.getPendingDumps();
      if (pendingDumps.isNotEmpty) {
        await _supabase.syncDumps(pendingDumps);
        for (final dump in pendingDumps) {
          await _localDb.updateDumpSyncStatus(dump.id, SyncStatus.synced);
        }
      }
    } catch (e) {
      print('Sync failed: \$e');
    }
  }
}
