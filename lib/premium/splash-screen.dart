import 'package:flutter/material.dart';

import '../services/service-config.dart';

/// The Pro upsell screen.
///
/// Oinkoin is currently free for everyone: [ServiceConfig.isPremium] defaults
/// to `true`, so no feature gate ever opens this screen. It is kept as a
/// placeholder so the gates that reference it keep compiling and the paywall
/// can be rebuilt where it belongs.
///
/// To bring the paywall back, restore the pieces the feature gates already
/// expect: the `in_app_purchase` dependency, a purchase service that writes
/// `PremiumLicenseStore` and calls `ServiceConfig.setPremium`, the entitlement
/// lookup at startup in `main.dart`, and the real upsell UI here (all of it is
/// in the git history). The paywall's translations were intentionally left in
/// `assets/locales`. Nothing here needs to change for paid features to work:
/// the gates and the PRO badge widget are untouched.
class PremiumSplashScreen extends StatelessWidget {
  const PremiumSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: BackButton()),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            // Unreachable in every current build: no translation key is
            // needed for a placeholder that no user can see.
            'Oinkoin is free for everyone.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
    );
  }
}
