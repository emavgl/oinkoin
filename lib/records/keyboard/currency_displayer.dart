import 'dart:ui';

import 'package:flutter/material.dart';

class CurrencyDisplayer extends StatelessWidget {
  /// Creates a widget that takes an amount and display it in a localized currency
  /// format with the decimals smaller that the rest of the text.
  ///
  /// This widget is not in charge of the conversion to any currency,
  /// that is, the amount will be remain as it is specified in
  /// the `amountToConvert` attribute.
  const CurrencyDisplayer({
    super.key,
    required this.amountToConvert,
    this.currency,
    this.showDecimals = true,
    this.integerStyle = const TextStyle(inherit: true),
    this.decimalsStyle,
    this.currencyStyle,
    this.followPrivateMode = true,
    this.compactView = false,
  });

  final double amountToConvert;

  /// If `true` (the default value), the widget will display the amount with a
  /// blurred effect if the user has the private mode activated
  final bool followPrivateMode;

  /// The currency of the amount, used to display the symbol.
  /// If not specified, will be the user preferred currency
  final CurrencyInDB? currency;

  /// Style of the text that corresponds to the integer part of the number to be displayed
  final TextStyle integerStyle;

  /// Style of the text that corresponds to the integer part of the number to be displayed.
  /// If not defined, we will try to use a less prominent style than the one used in the integer
  /// part of the number
  final TextStyle? decimalsStyle;

  /// Style of the text that corresponds to the currency symbol. By default will be
  /// the same as the `decimalStyle`. This property is only defined and
  /// used if the `UINumberFormatterMode` of this Widget is set to `currency`.
  final TextStyle? currencyStyle;

  final bool showDecimals;
  final bool compactView;

  Widget _amountDisplayer(
    BuildContext context, {
    required CurrencyInDB currency,
  }) {
    return UINumberFormatter.currency(
      amountToConvert: amountToConvert,
      currency: currency,
      showDecimals: showDecimals,
      integerStyle: integerStyle,
      decimalsStyle: decimalsStyle,
      currencyStyle: currencyStyle,
      compactView: compactView,
    ).getTextWidget(context);
  }

  @override
  Widget build(BuildContext context) {
    final valueFontSize =
        (integerStyle.fontSize ??
            DefaultTextStyle.of(context).style.fontSize) ??
        16;

    if (currency != null) {
      final displayer = _amountDisplayer(context, currency: currency!);

      if (followPrivateMode) {
        return BlurBasedOnPrivateMode(child: displayer);
      } else {
        return displayer;
      }
    }

    return StreamBuilder(
      stream: CurrencyService.instance.ensureAndGetPreferredCurrency(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Skeletonizer.zone(
            child: Bone(
              height: valueFontSize,
              width: 40 + valueFontSize,
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }

        final displayer = _amountDisplayer(context, currency: snapshot.data!);

        if (followPrivateMode) {
          return BlurBasedOnPrivateMode(child: displayer);
        } else {
          return displayer;
        }
      },
    );
  }
}

class BlurBasedOnPrivateMode extends StatelessWidget {
  const BlurBasedOnPrivateMode({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: PrivateModeService.instance.privateModeStream,
      initialData: appStateSettings[SettingKey.privateModeAtLaunch] == '1',
      builder: (context, snapshot) {
        final isInPrivateMode = snapshot.data ?? false;

        final double sigma = isInPrivateMode ? 7.5 : 0;

        return ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: child,
        );
      },
    );
  }
}
