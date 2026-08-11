import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/services/service-config.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('getBackgroundImage', () {
    setUp(() async {
      // Reset ServiceConfig to defaults before each test
      ServiceConfig.isPremium = true;
      ServiceConfig.sharedPreferences = null;
    });

    test('returns default image when not premium', () async {
      ServiceConfig.isPremium = false;
      SharedPreferences.setMockInitialValues({});
      ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();

      final result = getBackgroundImage(1);
      expect((result as AssetImage).assetName, 'assets/images/bkg-default.png');
    });

    test('returns default image on invalid month index', () async {
      SharedPreferences.setMockInitialValues({});
      ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();

      final result = getBackgroundImage(-1);
      expect((result as AssetImage).assetName, 'assets/images/bkg-default.png');
    });

    test('returns default image on month index 0', () async {
      SharedPreferences.setMockInitialValues({});
      ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();

      final result = getBackgroundImage(0);
      expect((result as AssetImage).assetName, 'assets/images/bkg-default.png');
    });

    test('returns default image on month index 13', () async {
      SharedPreferences.setMockInitialValues({});
      ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();

      final result = getBackgroundImage(13);
      expect((result as AssetImage).assetName, 'assets/images/bkg-default.png');
    });

    group('without reversal (default)', () {
      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();
      });

      test('month 1 returns January image', () {
        final result = getBackgroundImage(1);
        expect((result as AssetImage).assetName, 'assets/images/bkg-1.png');
      });

      test('month 6 returns June image', () {
        final result = getBackgroundImage(6);
        expect((result as AssetImage).assetName, 'assets/images/bkg-6.png');
      });

      test('month 7 returns July image', () {
        final result = getBackgroundImage(7);
        expect((result as AssetImage).assetName, 'assets/images/bkg-7.png');
      });

      test('month 12 returns December image', () {
        final result = getBackgroundImage(12);
        expect((result as AssetImage).assetName, 'assets/images/bkg-12.png');
      });
    });

    group('when sharedPreferences is null', () {
      test('defaults to no reversal when preferences not initialized', () {
        // ServiceConfig.sharedPreferences is null
        ServiceConfig.isPremium = true;
        // This should not crash and should return the normal image
        final result = getBackgroundImage(3);
        expect((result as AssetImage).assetName, 'assets/images/bkg-3.png');
      });
    });

    group('with user-assigned banner images', () {
      late Directory tempDir;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('banner_test');
      });

      tearDown(() async {
        await tempDir.delete(recursive: true);
      });

      test('returns the user image when a month has an assignment', () async {
        final file = File('${tempDir.path}${Platform.pathSeparator}custom.png');
        await file.writeAsBytes([1, 2, 3]);
        SharedPreferences.setMockInitialValues({
          'monthlyBannerAssignments': '{"3":"user:${file.path}"}',
        });
        ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();

        final result = getBackgroundImage(3);
        expect(result, isA<FileImage>());
        expect((result as FileImage).file.path, file.path);
      });

      test('falls back to the month image for unassigned months', () async {
        SharedPreferences.setMockInitialValues({
          'monthlyBannerAssignments': '{"3":"asset:assets/images/bkg-1.png"}',
        });
        ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();

        final result = getBackgroundImage(5);
        expect((result as AssetImage).assetName, 'assets/images/bkg-5.png');
      });

      test('falls back to default when the user file does not exist', () async {
        SharedPreferences.setMockInitialValues({
          'monthlyBannerAssignments': '{"3":"user:/nonexistent/custom.png"}',
        });
        ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();

        final result = getBackgroundImage(3);
        expect(
            (result as AssetImage).assetName, 'assets/images/bkg-default.png');
      });

      test('returns default image for non-premium even with assignment',
          () async {
        ServiceConfig.isPremium = false;
        SharedPreferences.setMockInitialValues({
          'monthlyBannerAssignments': '{"3":"user:/some/path.png"}',
        });
        ServiceConfig.sharedPreferences = await SharedPreferences.getInstance();

        final result = getBackgroundImage(3);
        expect(
            (result as AssetImage).assetName, 'assets/images/bkg-default.png');
      });
    });
  });
}
