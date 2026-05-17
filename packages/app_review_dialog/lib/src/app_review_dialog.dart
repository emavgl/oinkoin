import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'strings.dart';

/// Result returned by [AppReviewDialog.show].
enum AppReviewDialogAction { ratedPositive, ratedNegative, dismissed }

class AppReviewDialogResult {
  final double rating;
  final AppReviewDialogAction action;

  const AppReviewDialogResult(this.rating, this.action);

  @override
  String toString() => 'AppReviewDialogResult($rating, $action)';
}

// ---------------------------------------------------------------------------
// Static entry point
// ---------------------------------------------------------------------------

/// Shows the review dialog and returns the result.
///
/// [supportEmail] is **required**. [storePackageName] and
/// [supportWebsitePage] are optional.
///
/// If [locale] is not provided, the device locale is auto-detected.
// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

class AppReviewDialog extends StatefulWidget {
  /// Shows the review dialog and returns the result.
  ///
  /// [supportEmail] is **required**. [storePackageName] and
  /// [supportWebsitePage] are optional.
  ///
  /// If [locale] is not provided, the device locale is auto-detected.
  /// Every string shown in the dialog can be overridden.
  static Future<AppReviewDialogResult?> show(
    BuildContext context, {
    required String supportEmail,
    String? storePackageName,
    String? appStoreId,
    String? supportWebsitePage,
    double minPositiveRating = 3.5,
    Locale? locale,
    String? title,
    String? ratingLabel,
    String? positiveTitle,
    String? positiveSubtitle,
    String? negativeTitle,
    String? negativeSubtitle,
    String? rateButtonLabel,
    String? supportButtonLabel,
    String? emailButtonLabel,
    String? continueButtonLabel,
  }) {
    return showDialog<AppReviewDialogResult>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AppReviewDialog(
        supportEmail: supportEmail,
        storePackageName: storePackageName,
        appStoreId: appStoreId,
        supportWebsitePage: supportWebsitePage,
        minPositiveRating: minPositiveRating,
        locale: locale ?? _detectLocale(),
        title: title,
        ratingLabel: ratingLabel,
        positiveTitle: positiveTitle,
        positiveSubtitle: positiveSubtitle,
        negativeTitle: negativeTitle,
        negativeSubtitle: negativeSubtitle,
        rateButtonLabel: rateButtonLabel,
        supportButtonLabel: supportButtonLabel,
        emailButtonLabel: emailButtonLabel,
        continueButtonLabel: continueButtonLabel,
      ),
    );
  }

  static Locale _detectLocale() {
    try {
      final localeName = Platform.localeName;
      final parts = localeName.split('_');
      if (parts.length == 2) return Locale(parts[0], parts[1]);
      return Locale(parts[0]);
    } catch (_) {
      return const Locale('en');
    }
  }
  final String supportEmail;
  final String? storePackageName;
  final String? appStoreId;
  final String? supportWebsitePage;
  final double minPositiveRating;
  final Locale locale;

  // String overrides
  final String? title;
  final String? ratingLabel;
  final String? positiveTitle;
  final String? positiveSubtitle;
  final String? negativeTitle;
  final String? negativeSubtitle;
  final String? rateButtonLabel;
  final String? supportButtonLabel;
  final String? emailButtonLabel;
  final String? continueButtonLabel;

  const AppReviewDialog({
    super.key,
    required this.supportEmail,
    this.storePackageName,
    this.appStoreId,
    this.supportWebsitePage,
    this.minPositiveRating = 3.5,
    required this.locale,
    this.title,
    this.ratingLabel,
    this.positiveTitle,
    this.positiveSubtitle,
    this.negativeTitle,
    this.negativeSubtitle,
    this.rateButtonLabel,
    this.supportButtonLabel,
    this.emailButtonLabel,
    this.continueButtonLabel,
  });

  @override
  State<AppReviewDialog> createState() => _AppReviewDialogState();
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

enum _Screen { rating, positive, negative }

class _AppReviewDialogState extends State<AppReviewDialog> {
  double _rating = 0.0;
  _Screen _screen = _Screen.rating;
  int _lastTappedIndex = -1;

  static const _starCount = 5;
  static const _starSize = 44.0;

  bool get _showRateButton =>
      widget.storePackageName != null || widget.appStoreId != null;

  // Lookup the closest-matching localised string
  String _l(String? override, String Function(AppReviewStrings s) selector) {
    if (override != null) return override;
    final s = AppReviewStrings.lookup(widget.locale);
    return selector(s);
  }

  // Star hit detection ---------------------------------------------

  void _onTapDown(TapDownDetails d) {
    final localDx = d.localPosition.dx;
    if (localDx < 0 || localDx > _starSize * _starCount) return;
    final idx = (localDx / _starSize).floor();
    setState(() {
      _rating = idx + 1.0;
      _lastTappedIndex = idx;
    });
  }

  void _onContinue() {
    setState(() {
      _screen = _rating >= widget.minPositiveRating
          ? _Screen.positive
          : _Screen.negative;
    });
  }

  // Actions ---------------------------------------------------------

  void _dismiss() {
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

  void _rateInStore() {
    if (Platform.isAndroid && widget.storePackageName != null) {
      _openUrl('market://details?id=${widget.storePackageName}',
          httpsFallback:
              'https://play.google.com/store/apps/details?id=${widget.storePackageName}');
    } else if (Platform.isIOS && widget.appStoreId != null) {
      _openUrl(
          'itms-apps://itunes.apple.com/app/id${widget.appStoreId}',
          httpsFallback:
              'https://apps.apple.com/app/id${widget.appStoreId}');
    }
    Navigator.of(context).pop(
      AppReviewDialogResult(_rating, AppReviewDialogAction.ratedPositive),
    );
  }

  void _openSupport() {
    if (widget.supportWebsitePage != null) {
      _openUrl(widget.supportWebsitePage!);
    }
    Navigator.of(context).pop(
      AppReviewDialogResult(_rating, AppReviewDialogAction.ratedPositive),
    );
  }

  void _sendEmail() {
    _openUrl('mailto:${widget.supportEmail}'
        '?subject=App Feedback'
        '&body=');
    Navigator.of(context).pop(
      AppReviewDialogResult(_rating, AppReviewDialogAction.ratedNegative),
    );
  }

  // Build -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return WillPopScope(
      onWillPop: () async {
        _dismiss();
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
            child: _body(cs),
          ),
        ),
      ),
    );
  }

  Widget _body(ColorScheme cs) {
    switch (_screen) {
      case _Screen.rating:
        return _buildRating(cs);
      case _Screen.positive:
        return _buildPositive(cs);
      case _Screen.negative:
        return _buildNegative(cs);
    }
  }

  // -- Rating -------------------------------------------------------

  Widget _buildRating(ColorScheme cs) {
    final cancelLabel = MaterialLocalizations.of(context).cancelButtonLabel;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_l(widget.title, (s) => s.title),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: cs.onSurface),
            textAlign: TextAlign.center),
        const SizedBox(height: 24),
        GestureDetector(
          onTapDown: _onTapDown,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: _starSize * _starCount,
            height: _starSize,
            child: Row(
              children: List.generate(_starCount, (i) {
                final filled = i < _rating.round();
                final icon = filled ? Icons.star : Icons.star_border;
                final justTapped = i == _lastTappedIndex;
                return TweenAnimationBuilder<double>(
                  key: ValueKey('$_rating${justTapped ? '_tap' : ''}_$i'),
                  tween: Tween(begin: justTapped ? 0.3 : 1.0, end: 1.0),
                  duration: Duration(milliseconds: justTapped ? 600 : 0),
                  curve: justTapped ? Curves.elasticOut : Curves.linear,
                  builder: (_, value, __) {
                    return Transform.scale(
                      scale: value.clamp(0.0, 1.0),
                      child: Icon(icon, size: _starSize, color: cs.primary),
                    );
                  },
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _dismiss,
                child: Text(cancelLabel),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _rating > 0 ? _onContinue : null,
                child: Text(_l(widget.continueButtonLabel, (s) => s.continueLabel)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // -- Negative -----------------------------------------------------

  Widget _buildNegative(ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 4),
        Icon(Icons.mail_outline, size: 40, color: cs.primary),
        const SizedBox(height: 16),
        Text(_l(widget.negativeTitle, (s) => s.negativeTitle),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: cs.onSurface),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(_l(widget.negativeSubtitle, (s) => s.negativeSubtitle),
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
            textAlign: TextAlign.center),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _sendEmail,
            child: Text(_l(widget.emailButtonLabel, (s) => s.emailButtonLabel)),
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

  // -- Positive -----------------------------------------------------

  Widget _buildPositive(ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 4),
        Icon(Icons.favorite, size: 40, color: cs.primary),
        const SizedBox(height: 16),
        Text(_l(widget.positiveTitle, (s) => s.positiveTitle),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: cs.onSurface),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(_l(widget.positiveSubtitle, (s) => s.positiveSubtitle),
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
            textAlign: TextAlign.center),
        const SizedBox(height: 24),
        if (_showRateButton) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _rateInStore,
              child: Text(_l(widget.rateButtonLabel, (s) => s.rateButtonLabel)),
            ),
          ),
        ],
        if (widget.supportWebsitePage != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _openSupport,
              child: Text(_l(widget.supportButtonLabel, (s) => s.supportButtonLabel)),
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
