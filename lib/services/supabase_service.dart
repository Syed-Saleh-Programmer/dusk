import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dump.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  // Dumps
  Future<void> syncDumps(List<Dump> pendingDumps) async {
    for (final dump in pendingDumps) {
      try {
        await _client.from('dumps').upsert(dump.toMap());
        // Note: The LocalDbService should update the sync status locally after this succeeds
      } catch (e) {
        print('Error syncing dump \${dump.id}: \$e');
      }
    }
  }

  // Mocks for Auth since we don't have real credentials yet
  Future<void> signIn(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUp(String email, String password) async {
    await _client.auth.signUp(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  User? get currentUser => _client.auth.currentUser;
}
