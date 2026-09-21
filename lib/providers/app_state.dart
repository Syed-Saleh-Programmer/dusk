import 'package:flutter/material.dart';
import '../models/dump.dart';
import '../models/reflection_cycle.dart';
import '../services/local_db_service.dart';
import '../services/supabase_service.dart';

class AppState extends ChangeNotifier {
  final LocalDbService _localDb = LocalDbService();
  
  List<Dump> _pendingDumps = [];
  List<Dump> get pendingDumps => _pendingDumps;
  
  ReflectionCycle? _currentCycle;
  ReflectionCycle? get currentCycle => _currentCycle;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  AppState() {
    _init();
  }

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();
    
    await fetchPendingDumps();
    await fetchCurrentCycle();
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchCurrentCycle() async {
    _currentCycle = await SupabaseService().getOrCreateCurrentCycle();
    notifyListeners();
  }

  Future<void> fetchPendingDumps() async {
    _pendingDumps = await _localDb.getPendingDumps();
    notifyListeners();
  }

  void setCurrentCycle(ReflectionCycle cycle) {
    _currentCycle = cycle;
    notifyListeners();
  }
}
