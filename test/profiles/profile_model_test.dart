import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/profile.dart';

void main() {
  group('Profile model — serialization', () {
    test('toMap writes name correctly', () {
      final profile = Profile('Work');
      expect(profile.toMap()['name'], 'Work');
    });

    test('toMap writes is_default = 1 for default profiles', () {
      final profile = Profile('Default', isDefault: true);
      expect(profile.toMap()['is_default'], 1);
    });

    test('toMap writes is_default = 0 for non-default profiles', () {
      final profile = Profile('Work');
      expect(profile.toMap()['is_default'], 0);
    });

    test('toMap includes id when set', () {
      final profile = Profile('Travel', id: 42);
      expect(profile.toMap()['id'], 42);
    });

    test('toMap includes null id when not set', () {
      final profile = Profile('Travel');
      expect(profile.toMap()['id'], isNull);
    });
  });

  group('Profile model — deserialization', () {
    test('fromMap reads name correctly', () {
      final profile = Profile.fromMap({'id': 1, 'name': 'Work', 'is_default': 0});
      expect(profile.name, 'Work');
    });

    test('fromMap reads id correctly', () {
      final profile = Profile.fromMap({'id': 7, 'name': 'Family', 'is_default': 0});
      expect(profile.id, 7);
    });

    test('fromMap sets isDefault = true when is_default = 1', () {
      final profile = Profile.fromMap({'id': 1, 'name': 'Default', 'is_default': 1});
      expect(profile.isDefault, isTrue);
    });

    test('fromMap sets isDefault = false when is_default = 0', () {
      final profile = Profile.fromMap({'id': 2, 'name': 'Work', 'is_default': 0});
      expect(profile.isDefault, isFalse);
    });

    test('fromMap defaults isDefault to false when is_default key is absent', () {
      final profile = Profile.fromMap({'id': 3, 'name': 'Test'});
      expect(profile.isDefault, isFalse);
    });
  });

  group('Profile model — round-trip', () {
    test('toMap then fromMap preserves all fields', () {
      final original = Profile('Vacation', id: 5, isDefault: true);
      final roundTripped = Profile.fromMap(original.toMap());
      expect(roundTripped.id, original.id);
      expect(roundTripped.name, original.name);
      expect(roundTripped.isDefault, original.isDefault);
    });

    test('non-default profile survives round-trip intact', () {
      final original = Profile('Budget', id: 12, isDefault: false);
      final roundTripped = Profile.fromMap(original.toMap());
      expect(roundTripped.id, 12);
      expect(roundTripped.name, 'Budget');
      expect(roundTripped.isDefault, isFalse);
    });

    test('profile with no id produces null id after round-trip', () {
      // Simulates what happens when toMap is used for a fresh INSERT
      // (id is null → auto-assigned by the database)
      final original = Profile('New Profile');
      final map = original.toMap();
      expect(map['id'], isNull);
    });
  });
}
