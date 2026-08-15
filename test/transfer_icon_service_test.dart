import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/category-icons.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:piggybank/services/transfer-icon-service.dart';
import 'package:piggybank/settings/constants/preferences-keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
  });

  tearDown(() {
    ServiceConfig.sharedPreferences = null;
  });

  test('uses the default transfer icon when no customization is saved', () {
    expect(TransferIconService.icon, Icons.swap_horiz);
    expect(TransferIconService.iconEmoji, isNull);
    expect(
        TransferIconService.color?.toARGB32(), Colors.grey[400]!.toARGB32());
  });

  test('round-trips a selected icon and color', () async {
    final icon = CategoryIcons.pro_category_icons.first;
    final color = Colors.purple;

    await TransferIconService.save(iconEmoji: null, icon: icon, color: color);

    expect(TransferIconService.icon, icon);
    expect(TransferIconService.iconEmoji, isNull);
    expect(TransferIconService.color?.toARGB32(), color.toARGB32());
  });

  test('round-trips an emoji and clears the previous icon', () async {
    await TransferIconService.save(
      iconEmoji: '🔄',
      icon: Icons.swap_horiz,
      color: null,
    );

    expect(TransferIconService.iconEmoji, '🔄');
    expect(TransferIconService.icon, Icons.swap_horiz);
    expect(
        TransferIconService.color?.toARGB32(), Colors.grey[400]!.toARGB32());
  });

  test('falls back safely for an unknown icon code point', () async {
    await ServiceConfig.sharedPreferences!.setInt(
        PreferencesKeys.transferIconCodePoint, 123456789);

    expect(TransferIconService.icon, Icons.swap_horiz);
  });

  test('reset restores the original icon aspect', () async {
    await TransferIconService.save(
      iconEmoji: '🔄',
      icon: CategoryIcons.pro_category_icons.first,
      color: Colors.purple,
    );

    await TransferIconService.reset();

    expect(TransferIconService.icon, Icons.swap_horiz);
    expect(TransferIconService.iconEmoji, isNull);
    expect(
        TransferIconService.color?.toARGB32(), Colors.grey[400]!.toARGB32());
  });
}
