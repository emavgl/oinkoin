import 'package:shared_preferences/shared_preferences.dart';

/// Manages the review dialog prompt logic: when to show it, and how the
/// record-count threshold evolves after dismissals.
///
/// - First prompt: 50 records
/// - Each dismissal: threshold += 10 (anchored to the current record count)
/// - Engagement (user rates and proceeds): permanently silenced
class ReviewPromptService {
  static const _shownKey = 'app_review_dialog_shown';
  static const _thresholdKey = 'app_review_dialog_next_threshold';

  static const defaultThreshold = 50;
  static const thresholdIncrement = 10;

  final SharedPreferences _prefs;

  ReviewPromptService(this._prefs);

  /// Whether the dialog has been permanently marked as shown (user engaged).
  bool get isPermanentlyShown => _prefs.getBool(_shownKey) == true;

  /// The minimum record count required to show the next prompt.
  int get nextThreshold => _prefs.getInt(_thresholdKey) ?? defaultThreshold;

  /// Whether the dialog should be shown given the current [recordCount].
  bool shouldShow(int recordCount) {
    if (isPermanentlyShown) return false;
    return recordCount >= nextThreshold;
  }

  /// Called when the user engages with the dialog (rates and proceeds past the
  /// initial star screen). Silences the dialog permanently.
  Future<void> markPermanentlyShown() => _prefs.setBool(_shownKey, true);

  /// Called when the user dismisses the dialog (Cancel, tap outside, back).
  /// Bumps the threshold so the dialog reappears at a higher record count.
  Future<void> markDismissed(int currentRecordCount) =>
      _prefs.setInt(_thresholdKey, currentRecordCount + thresholdIncrement);
}
