import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_review_localizations.dart';

/// Result returned by [AppReviewDialog.show].
///
/// [rating] is the star count the user selected (0.0 – 5.0, half-step).
/// [action] describes what happened after rating.
enum AppReviewDialogAction { ratedPositive, ratedNegative, dismissed }

class AppReviewDialogResult {
  final double rating;
  final AppReviewDialogAction action;

  const AppReviewDialogResult(this.rating, this.action);

  @override
  String toString() => 'AppReviewDialogResult($rating, $action)';
}

// ---------------------------------------------------------------------------
// Static entry points
// ---------------------------------------------------------------------------

/// Shows the review dialog and returns the result when the dialog is closed.
///
/// All string overrides are optional; whenever omitted, the default
/// localised text is used.
///
/// [context], [supportEmail] are **required**.
Future<AppReviewDialogResult?> show(
  BuildContext context, {
  required String supportEmail,
  String? supportWebsitePage,
  String? storePackageName,
  double minPositiveRating = 3.5,
  String? title,
  String? positiveTitle,
  String? positiveSubtitle,
  String? negativeTitle,
  String? negativeSubtitle,
  String? ratingLabel,
  String? rateButtonLabel,
  String? supportButtonLabel,
  String? emailButtonLabel,
}) {
  return showDialog<AppReviewDialogResult>(
    context: context,
    barrierDismissible: true,
    builder: (_) => AppReviewDialog(
      supportEmail: supportEmail,
      supportWebsitePage: supportWebsitePage,
      storePackageName: storePackageName,
      minPositiveRating: minPositiveRating,
      title: title,
      positiveTitle: positiveTitle,
      positiveSubtitle: positiveSubtitle,
      negativeTitle: negativeTitle,
      negativeSubtitle: negativeSubtitle,
      ratingLabel: ratingLabel,
      rateButtonLabel: rateButtonLabel,
      supportButtonLabel: supportButtonLabel,
      emailButtonLabel: emailButtonLabel,
    ),
  );
}

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

class AppReviewDialog extends StatefulWidget {
  /// Email address for the feedback button (mandatory).
  final String supportEmail;

  /// URL of the support/contribute web page (optional).
  /// If provided, a "Support & Contribute" button appears on the positive path.
  final String? supportWebsitePage;

  /// Google Play package name (e.g. `com.example.app`) for the "Rate in store"
  /// button.  The dialog constructs a `market://details?id=…` deep link
  /// automatically, falling back to the https Play Store URL if needed.
  ///
  /// If not provided the button still pops with
  /// [AppReviewDialogAction.ratedPositive] so the caller can handle the rating
  /// themselves.
  final String? storePackageName;

  /// Rating (0–5) above which the positive flow is shown. Default 3.5.
  final double minPositiveRating;

  // -- string overrides (null → use localised default) --

  /// Dialog title before the user has rated.
  final String? title;

  /// Title shown when rating >= [minPositiveRating].
  final String? positiveTitle;

  /// Subtitle shown when rating >= [minPositiveRating].
  final String? positiveSubtitle;

  /// Title shown when rating < [minPositiveRating].
  final String? negativeTitle;

  /// Subtitle shown when rating < [minPositiveRating].
  final String? negativeSubtitle;

  /// Instruction text shown above the stars.
  final String? ratingLabel;

  /// Label for the “Rate in Store” button.
  final String? rateButtonLabel;

  /// Label for the “Support & Contribute” button.
  final String? supportButtonLabel;

  /// Label for the “Send Feedback” email button.
  final String? emailButtonLabel;

  const AppReviewDialog({
    super.key,
    required this.supportEmail,
    this.supportWebsitePage,
    this.storePackageName,
    this.minPositiveRating = 3.5,
    this.title,
    this.positiveTitle,
    this.positiveSubtitle,
    this.negativeTitle,
    this.negativeSubtitle,
    this.ratingLabel,
    this.rateButtonLabel,
    this.supportButtonLabel,
    this.emailButtonLabel,
  });

  @override
  State<AppReviewDialog> createState() => _AppReviewDialogState();
}

enum _Screen { rating, positive, negative }

class _AppReviewDialogState extends State<AppReviewDialog> {
  double _rating = 0.0;
  _Screen _screen = _Screen.rating;

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  AppReviewLocalizations _l10n() => AppReviewLocalizations.of(context);

  String _s(String? override, String Function(AppReviewLocalizations l) def) =>
      override ?? def(_l10n());

  // Star layout
  static const _starCount = 5;
  static const _starSize = 44.0;

  // Half-star hit zones
  int? _starIndexFromPosition(double localDx) {
    final fullStar = _starSize * _starCount;
    if (localDx < 0 || localDx > fullStar + 8) return null;

    // Clamp into 0 … _starCount
    int idx = (localDx / _starSize).floor();
    if (idx < 0) idx = 0;
    if (idx >= _starCount) idx = _starCount - 1;

    return idx;
  }

  double _ratingForStar(int idx, double localDx) {
    final fraction = (localDx - idx * _starSize) / _starSize;
    // First 35% → empty (keep idx), 35-65% → half, 65+% → full
    if (fraction < 0.35) return idx.toDouble();
    if (fraction < 0.65) return idx + 0.5;
    return idx + 1.0;
  }

  void _onTapDown(TapDownDetails d) {
    final box = context.findRenderObject() as RenderBox;
    final local = box.globalToLocal(d.globalPosition);
    final idx = _starIndexFromPosition(local.dx);
    if (idx == null || _rating > 0) return; // already rated
    final newRating = _ratingForStar(idx, local.dx);
    setState(() { _rating = newRating; });
    // After brief animation, switch screen
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _screen = _rating >= widget.minPositiveRating
            ? _Screen.positive
            : _Screen.negative;
      });
    });
  }

  // -----------------------------------------------------------------------
  // Lifecycle
  // -----------------------------------------------------------------------



  // -----------------------------------------------------------------------
  // Actions
  // -----------------------------------------------------------------------

  Future<void> _dismiss() async {
    Navigator.of(context).pop(
      AppReviewDialogResult(_rating, AppReviewDialogAction.dismissed),
    );
  }

  Future<void> _openUrl(String url, {String? httpsFallback}) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (httpsFallback != null) {
      final fbUri = Uri.parse(httpsFallback);
      if (await canLaunchUrl(fbUri)) {
        await launchUrl(fbUri, mode: LaunchMode.externalApplication);
      }
    }
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(
          AppReviewDialogResult(_rating, AppReviewDialogAction.dismissed),
        );
        return false;
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: _buildBody(colorScheme),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    switch (_screen) {
      case _Screen.rating:
        return _buildRating(cs);
      case _Screen.positive:
        return _buildPositive(cs);
      case _Screen.negative:
        return _buildNegative(cs);
    }
  }

  // -- Rating step -----------------------------------------------

  Widget _buildRating(ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _s(widget.title, (l) => l.title),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        // Stars
        GestureDetector(
          onTapDown: _onTapDown,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            height: _starSize,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_starCount, (i) {
                final filled = _rating - i;
                IconData icon;
                if (filled >= 1.0) {
                  icon = Icons.star;
                } else if (filled >= 0.5) {
                  icon = Icons.star_half;
                } else {
                  icon = Icons.star_border;
                }
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutBack,
                  builder: (_, value, __) {
                    final t = value.clamp(0.0, 1.0);
                        return Transform.scale(
                      scale: t,
                        child: Icon(
                          icon,
                          size: _starSize,
                          color: cs.primary,
                        ),
                      );
                    },
                  );
              }),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _s(widget.ratingLabel, (l) => l.ratingLabel),
          style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: _dismiss,
          child: Text(
            MaterialLocalizations.of(context).cancelButtonLabel,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  // -- Negative outcome ------------------------------------------

  Widget _buildNegative(ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 4),
        Icon(Icons.mail_outline, size: 40, color: cs.primary),
        const SizedBox(height: 16),
        Text(
          _s(widget.negativeTitle, (l) => l.negativeTitle),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _s(widget.negativeSubtitle, (l) => l.negativeSubtitle),
          style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              _openUrl('mailto:${widget.supportEmail}'
                  '?subject=App Feedback'
                  '&body=');
              Navigator.of(context).pop(
                AppReviewDialogResult(
                  _rating,
                  AppReviewDialogAction.ratedNegative,
                ),
              );
            },
            child: Text(
              _s(widget.emailButtonLabel, (l) => l.emailButtonLabel),
            ),
          ),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: _dismiss,
          child: Text(
            MaterialLocalizations.of(context).cancelButtonLabel,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  // -- Positive outcome ------------------------------------------

  Widget _buildPositive(ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 4),
        Icon(Icons.favorite, size: 40, color: cs.primary),
        const SizedBox(height: 16),
        Text(
          _s(widget.positiveTitle, (l) => l.positiveTitle),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _s(widget.positiveSubtitle, (l) => l.positiveSubtitle),
          style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              if (widget.storePackageName != null) {
                // Try the Play Store deep link first
                _openUrl('market://details?id=${widget.storePackageName}',
                    httpsFallback:
                        'https://play.google.com/store/apps/details?id=${widget.storePackageName}');
              }
              Navigator.of(context).pop(
                AppReviewDialogResult(
                  _rating,
                  AppReviewDialogAction.ratedPositive,
                ),
              );
            },
            child: Text(
              _s(widget.rateButtonLabel, (l) => l.rateButtonLabel),
            ),
          ),
        ),
        if (widget.supportWebsitePage != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                _openUrl(widget.supportWebsitePage!);
                Navigator.of(context).pop(
                  AppReviewDialogResult(
                    _rating,
                    AppReviewDialogAction.ratedPositive,
                  ),
                );
              },
              child: Text(
                _s(widget.supportButtonLabel, (l) => l.supportButtonLabel),
              ),
            ),
          ),
        ],
        const SizedBox(height: 4),
        TextButton(
          onPressed: _dismiss,
          child: Text(
            MaterialLocalizations.of(context).cancelButtonLabel,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
