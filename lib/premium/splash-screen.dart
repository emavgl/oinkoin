import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../i18n.dart';
import '../services/purchase-service.dart';
import '../services/service-config.dart';

enum _PremiumSplashState { loading, ready, offline, demo }

/// The Pro upsell screen, styled after the photobooth project's
/// `PurchaseDialogFragment`: a full-bleed hero image on top with a floating
/// close bar, the Lifetime Pro CTA and a restore-purchases action.
///
/// The hero height adapts to the available height, while the feature list can
/// scroll independently when space is tight.
class PremiumSplashScreen extends StatefulWidget {
  const PremiumSplashScreen({super.key, this.purchaseService});

  /// Injectable for tests; defaults to the app-wide singleton.
  final PurchaseService? purchaseService;

  @override
  State<PremiumSplashScreen> createState() => _PremiumSplashScreenState();
}

class _PremiumSplashScreenState extends State<PremiumSplashScreen> {
  late final PurchaseService _service =
      widget.purchaseService ?? PurchaseService.instance;

  _PremiumSplashState _state = _PremiumSplashState.loading;
  ProProducts? _products;
  bool _buying = false;

  @override
  void initState() {
    super.initState();
    _load();
    ServiceConfig.premiumNotifier.addListener(_onPremiumChanged);
  }

  @override
  void dispose() {
    ServiceConfig.premiumNotifier.removeListener(_onPremiumChanged);
    super.dispose();
  }

  /// If the user became Pro while this screen is open (e.g. after completing
  /// the billing flow), celebrate and close.
  void _onPremiumChanged() {
    if (!mounted || !ServiceConfig.isPremium) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Welcome to Oinkoin Pro!'.i18n)));
    Navigator.of(context).pop();
  }

  Future<void> _load() async {
    setState(() => _state = _PremiumSplashState.loading);
    final products = await _service.getProducts();
    if (!mounted) return;
    if (products.isEmpty) {
      // Products not yet configured in the store: let developers preview the
      // offers in debug builds, show an offline state in release builds.
      setState(
        () => _state = kDebugMode
            ? _PremiumSplashState.demo
            : _PremiumSplashState.offline,
      );
      return;
    }
    setState(() {
      _products = products;
      _state = _PremiumSplashState.ready;
    });
  }

  Future<void> _buy() async {
    if (_buying) return;
    final details = _selectedDetails;
    if (details == null) return;

    setState(() => _buying = true);
    final launched = await _service.buy(details);
    if (!mounted) return;
    setState(() => _buying = false);
    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to start the purchase. Please try again.'.i18n),
        ),
      );
    }
  }

  Future<void> _restore() async {
    final result = await _service.restorePurchases();
    if (!mounted) return;
    final String message;
    if (result.found) {
      message = 'Purchases restored'.i18n;
    } else if (result.error != null) {
      message = 'Restore failed. Please try again.'.i18n;
    } else {
      message = 'No purchases to restore'.i18n;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _demoUnavailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Purchases are not available in demo mode.'),
      ),
    );
  }

  bool get _demo => _state == _PremiumSplashState.demo;

  ProductDetails? get _selectedDetails => _products?.oneTime;

  String get _selectedPrice =>
      _demo ? r'$4.99' : (_selectedDetails?.price ?? '');

  String get _ctaLabel => 'Get Lifetime Pro for %s'.i18n.fill([_selectedPrice]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Full-bleed hero that adapts to the screen, leaving room for the
          // offers below so the page never needs to scroll.
          final heroHeight = (constraints.maxHeight * 0.33).clamp(200.0, 310.0);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: heroHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildHero(context),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _buildTopBar(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
                  child: _buildContent(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Full-bleed hero: piggy-bank artwork on a wash, with a top scrim (keeps
  /// the floating bar readable) and a bottom fade into the page background.
  Widget _buildHero(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [scheme.primaryContainer, scheme.surface],
            ),
          ),
        ),
        // The square artwork contained in the hero box (fills the height,
        // centered horizontally).
        ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.white, Colors.transparent],
            stops: [0, 0.68, 1],
          ).createShader(bounds),
          child: Image.asset(
            'assets/images/paywall_hero.jpeg',
            fit: BoxFit.cover,
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.45),
                Colors.transparent,
              ],
              stops: const [0, 1],
            ),
          ),
        ),
      ],
    );
  }

  /// Floating close bar overlaid on the hero (mirrors the dialog layout).
  Widget _buildTopBar(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 8, right: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Close'.i18n,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (_state) {
      case _PremiumSplashState.loading:
        return const Center(child: CircularProgressIndicator());
      case _PremiumSplashState.offline:
        return Center(child: _buildOfflineState(context));
      case _PremiumSplashState.ready:
      case _PremiumSplashState.demo:
        return _buildOffers(context);
    }
  }

  Widget _buildOfflineState(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.cloud_off, size: 56, color: theme.colorScheme.outline),
        const SizedBox(height: 16),
        Text(
          'Unable to connect to the store. Check your connection and try again.'
              .i18n,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: _load, child: Text('Retry'.i18n)),
      ],
    );
  }

  Widget _buildOffers(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Headline + tagline.
        Text.rich(
          TextSpan(
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            children: [
              TextSpan(text: 'Upgrade to'.i18n),
              TextSpan(text: ' '),
              TextSpan(
                text: 'Oinkoin Pro'.i18n,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Unlock every feature of Oinkoin'.i18n,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        // The feature list gets the available width so each row can lay out
        // its text without unbounded constraints. It can scroll independently
        // on short screens instead of overflowing the paywall.
        Expanded(
          child: SingleChildScrollView(
            child: SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 28),
                  _FeatureRow('Backup/Restore the application data'.i18n),
                  _FeatureRow('Add recurrent expenses'.i18n),
                  _FeatureRow('Create wallets and budgets'.i18n),
                  _FeatureRow('Manage multiple currencies'.i18n),
                  _FeatureRow('And many more...'.i18n),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(fontSize: 16),
          ),
          onPressed: _buying ? null : (_demo ? _demoUnavailable : _buy),
          child: _buying
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_ctaLabel),
        ),
        const SizedBox(height: 4),
        TextButton(onPressed: _restore, child: Text('Restore purchases'.i18n)),
        if (_demo) ...[
          const SizedBox(height: 8),
          Text(
            'Demo mode: purchases are not available in this build.'.i18n,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
        ],
      ],
    );
  }
}

/// One amber-bulleted Pro feature line.
class _FeatureRow extends StatelessWidget {
  const _FeatureRow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            height: 10,
            width: 20,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.amber,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }
}
