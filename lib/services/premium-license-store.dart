import 'service-config.dart';

/// Persists the Oinkoin Pro entitlement, mirroring the `LicenseManager` of
/// the photobooth project.
///
/// The Play/App Store is the source of truth for purchases; this store is
/// only a local cache so Pro keeps working while the device is offline or the
/// store is unreachable.
///
/// Oinkoin currently sells nothing, so nothing writes or clears this cache any
/// more: it is kept exactly as the buyer left it, so Lifetime Pro purchases
/// made before billing was removed survive. When paid features return, a
/// purchase service refreshes it again on every app start (it used to be
/// `PurchaseService`, and the store reported whether a purchase was active).
///
/// The entitlement is permanent: the one-time Lifetime Pro purchase never
/// expires.
class PremiumLicenseStore {
  PremiumLicenseStore._();

  static const String _keyTier = 'premium_tier';
  static const String _keyPermanent = 'premium_permanent';

  static const String _tierFree = 'free';
  static const String _tierPro = 'pro';

  /// Whether the permanent Lifetime Pro entitlement is currently stored.
  static bool isPro() {
    final prefs = ServiceConfig.sharedPreferences;
    return prefs?.getString(_keyTier) == _tierPro &&
        (prefs?.getBool(_keyPermanent) ?? false);
  }

  /// Saves a permanent Pro entitlement (one-time purchase). It never expires,
  /// so the app stays Pro forever even if the store is never reached again.
  static Future<void> saveProPermanent() async {
    final prefs = ServiceConfig.sharedPreferences;
    if (prefs == null) return;
    await prefs.setString(_keyTier, _tierPro);
    await prefs.setBool(_keyPermanent, true);
  }

  /// Removes the stored Lifetime Pro entitlement.
  static Future<void> clear() async {
    final prefs = ServiceConfig.sharedPreferences;
    if (prefs == null) return;
    await prefs.setString(_keyTier, _tierFree);
    await prefs.setBool(_keyPermanent, false);
  }
}
