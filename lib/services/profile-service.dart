import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';

class ProfileService {
  ProfileService._();
  static final ProfileService instance = ProfileService._();

  int? _activeProfileId;

  int? get activeProfileId => _activeProfileId;

  /// Called once at app startup (after SharedPreferences is ready) to load
  /// or resolve the active profile ID.
  Future<void> initialize() async {
    // Always start with the predefined (is_default) profile so wallet filter
    // preferences and other per-profile settings are consistent on every launch.
    final defaultProfile = await ServiceConfig.database.getDefaultProfile();
    if (defaultProfile != null) {
      _activeProfileId = defaultProfile.id;
    } else {
      // Fallback: use the last saved profile if DB has no predefined one.
      final prefs = ServiceConfig.sharedPreferences!;
      _activeProfileId = prefs.getInt(PreferencesKeys.activeProfileId);
    }
  }

  Future<void> switchProfile(int newProfileId) async {
    _activeProfileId = newProfileId;
    final prefs = ServiceConfig.sharedPreferences!;
    await prefs.setInt(PreferencesKeys.activeProfileId, newProfileId);
  }
}
