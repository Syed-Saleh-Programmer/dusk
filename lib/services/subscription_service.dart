import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service managing RevenueCat subscriptions, entitlements, and offerings for Dusk.
///
/// Features:
/// - Real-time `isPro` status stream and ValueListenable.
/// - Automatic fallback to offline / test mode for demo and testing without network setup.
/// - Synchronization with Supabase authenticated user ID (`Purchases.logIn`).
/// - Full package offerings lookup (Monthly, Annual with trial, Lifetime non-consumable).
class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  // Entitlement configured in RevenueCat dashboard
  static const String entitlementPro = 'pro';

  // RevenueCat Public API Keys
  // For RevenueCat Shipathon Test Store (No Google Play / App Store verification needed):
  static const String testStoreApiKey = String.fromEnvironment(
    'REVENUECAT_TEST_KEY',
    defaultValue: 'test_SgRomNlDlAJUFFrISIBmeHvvBqL',
  );
  static const String androidApiKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_KEY',
    defaultValue: 'goog_dusk_revenuecat_shipathon_android',
  );
  static const String iosApiKey = String.fromEnvironment(
    'REVENUECAT_IOS_KEY',
    defaultValue: 'appl_dusk_revenuecat_shipathon_ios',
  );

  static const String _prefKeyCachedPro = 'dusk_monetization_cached_pro';

  final ValueNotifier<bool> isProNotifier = ValueNotifier<bool>(false);
  bool get isPro => isProNotifier.value;

  Offerings? _offerings;
  Offerings? get offerings => _offerings;

  CustomerInfo? _customerInfo;
  CustomerInfo? get customerInfo => _customerInfo;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  bool _isPurchasesConfigured = false;
  bool get isPurchasesConfigured => _isPurchasesConfigured;

  /// Callback notified whenever Pro status toggles (e.g. to trigger/stop background cloud sync)
  static void Function(bool isPro)? onProStatusChanged;

  /// Initializes RevenueCat Purchases SDK
  Future<void> initialize({String? userId}) async {
    if (_isInitialized) return;

    // 1. Hydrate cached status first so UI renders instantly with 0 delay
    try {
      final prefs = await SharedPreferences.getInstance();
      isProNotifier.value = prefs.getBool(_prefKeyCachedPro) ?? false;
    } catch (_) {}

    // 2. Select appropriate platform API key:
    // If a valid production store key is supplied, use it; otherwise use test store key
    final platformKey = kIsWeb
        ? ''
        : Platform.isAndroid
            ? androidApiKey.trim()
            : Platform.isIOS
                ? iosApiKey.trim()
                : '';

    // A real production key for Android starts with 'goog_' and for iOS starts with 'appl_'
    // and is not the placeholder key ('goog_dusk...' or 'appl_dusk...')
    final isRealPlatformKey = platformKey.isNotEmpty &&
        !platformKey.startsWith('goog_dusk') &&
        !platformKey.startsWith('appl_dusk') &&
        !platformKey.startsWith('test_') &&
        (platformKey.startsWith('goog_') || platformKey.startsWith('appl_'));

    String apiKey = '';
    if (isRealPlatformKey) {
      apiKey = platformKey;
    } else if (testStoreApiKey.trim().isNotEmpty) {
      // Use RevenueCat Test Store key for test purchases and Shipathon demo
      apiKey = testStoreApiKey.trim();
    }

    if (apiKey.isEmpty ||
        apiKey.startsWith('goog_dusk') ||
        apiKey.startsWith('appl_dusk')) {
      debugPrint('[SubscriptionService] No store or test key configured. Operating in standalone mode.');
      _isInitialized = true;
      _isPurchasesConfigured = false;
      return;
    }

    try {
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }

      final configuration = PurchasesConfiguration(apiKey);
      if (userId != null && userId.isNotEmpty) {
        configuration.appUserID = userId;
      }
      await Purchases.configure(configuration);
      _isPurchasesConfigured = true;

      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        _handleCustomerInfoUpdate(customerInfo);
      });

      final info = await Purchases.getCustomerInfo();
      _handleCustomerInfoUpdate(info);

      try {
        _offerings = await Purchases.getOfferings();
      } catch (e) {
        debugPrint('[SubscriptionService] Initial offerings lookup notice: $e');
      }

      _isInitialized = true;
      debugPrint('[SubscriptionService] RevenueCat successfully initialized with ${apiKey.startsWith('test_') ? 'Test Store' : 'Production'} key. Pro: $isPro');
    } catch (e) {
      debugPrint('[SubscriptionService] RevenueCat init notice: $e (Falling back to local cache/standalone mode)');
      _isInitialized = true;
      _isPurchasesConfigured = false;
    }
  }

  void _handleCustomerInfoUpdate(CustomerInfo info) {
    _customerInfo = info;
    final hasPro = info.entitlements.all[entitlementPro]?.isActive == true;
    _setProState(hasPro);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool(_prefKeyCachedPro, hasPro);
    });
  }

  void _setProState(bool proValue) {
    if (isProNotifier.value != proValue) {
      isProNotifier.value = proValue;
      onProStatusChanged?.call(proValue);
    }
  }

  /// Allows testers or reviewers in standalone/demo mode to test Pro functionality
  Future<bool> toggleProForTesting() async {
    final next = !isPro;
    _setProState(next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyCachedPro, next);
    } catch (_) {}
    return next;
  }

  /// Purchase a RevenueCat package (Monthly, Annual, or Lifetime)
  Future<bool> purchasePackage(Package package) async {
    if (!_isPurchasesConfigured) {
      debugPrint('[SubscriptionService] Purchases not configured (standalone mode).');
      return isPro;
    }
    try {
      final purchaseResult = await Purchases.purchase(PurchaseParams.package(package));
      final customerInfo = purchaseResult.customerInfo;
      final hasPro = customerInfo.entitlements.all[entitlementPro]?.isActive == true;
      _setProState(hasPro);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyCachedPro, hasPro);
      return hasPro;
    } catch (e) {
      debugPrint('[SubscriptionService] Purchase error: $e');
      rethrow;
    }
  }

  /// Restores previous purchases for the current App Store / Google Play account
  Future<bool> restorePurchases() async {
    if (!_isPurchasesConfigured) {
      debugPrint('[SubscriptionService] Purchases not configured (standalone mode).');
      return isPro;
    }
    try {
      final customerInfo = await Purchases.restorePurchases();
      final hasPro = customerInfo.entitlements.all[entitlementPro]?.isActive == true;
      _setProState(hasPro);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyCachedPro, hasPro);
      return hasPro;
    } catch (e) {
      debugPrint('[SubscriptionService] Restore purchases error: $e');
      rethrow;
    }
  }

  /// Links RevenueCat customer identity to the user's Supabase account ID
  Future<void> linkUserId(String? userId) async {
    if (!_isInitialized || !_isPurchasesConfigured) return;
    try {
      if (userId != null && userId.isNotEmpty) {
        final logInResult = await Purchases.logIn(userId);
        _handleCustomerInfoUpdate(logInResult.customerInfo);
      } else {
        final customerInfo = await Purchases.logOut();
        _handleCustomerInfoUpdate(customerInfo);
      }
    } catch (e) {
      debugPrint('[SubscriptionService] User link notice: $e');
    }
  }

  Future<void> refresh() async {
    if (!_isPurchasesConfigured) return;
    try {
      _offerings = await Purchases.getOfferings();
      final info = await Purchases.getCustomerInfo();
      _handleCustomerInfoUpdate(info);
    } catch (_) {}
  }
}
