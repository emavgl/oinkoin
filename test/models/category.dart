import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:piggybank/models/category-icons.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';

// Helper function to create a fully-populated Category object
Category _createFullCategory({
  String name = 'Test Category',
  Color color = Colors.blue,
  IconData icon = FontAwesomeIcons.house,
  CategoryType type = CategoryType.income,
  int recordCount = 10,
  String iconEmoji = '💸',
  bool isArchived = true,
  int sortOrder = 5,
}) {
  return Category(
    name,
    color: color,
    iconCodePoint: icon.codePoint,
    categoryType: type,
    lastUsed: DateTime(2023, 1, 1),
    recordCount: recordCount,
    iconEmoji: iconEmoji,
    isArchived: isArchived,
    sortOrder: sortOrder,
  );
}

void main() {
  group('Category Serialization (toMap/fromMap)', () {
    test(
        'should correctly serialize and deserialize a fully populated Category object',
        () {
      final now = DateTime(2023, 1, 1);
      final testCategory = _createFullCategory();
      testCategory.color = Colors.blue.shade300;

      final map = testCategory.toMap();
      final decodedCategory = Category.fromMap(map);

      // Verify all properties are correctly round-tripped
      expect(decodedCategory.name, equals('Test Category'));
      expect(decodedCategory.color, equals(Colors.blue.shade300));
      expect(decodedCategory.iconCodePoint, isNull);
      expect(decodedCategory.categoryType, equals(CategoryType.income));
      expect(decodedCategory.lastUsed?.millisecondsSinceEpoch,
          equals(now.millisecondsSinceEpoch));
      expect(decodedCategory.recordCount, equals(10));
      expect(decodedCategory.iconEmoji, equals('💸'));
      expect(decodedCategory.isArchived, isTrue);
      expect(decodedCategory.sortOrder, equals(5));

      // Use the custom equality operator for a final check
      expect(decodedCategory, equals(testCategory));
    });

    test('should correctly deserialize a minimal map with default values', () {
      final map = {
        'name': 'Minimal Category',
        'category_type': CategoryType.expense.index,
        'sort_order': 0,
        'is_archived': 0,
        'record_count': 0,
      };

      final decodedCategory = Category.fromMap(map);

      // Verify defaults from the constructor and fromMap
      expect(decodedCategory.name, equals('Minimal Category'));
      expect(decodedCategory.categoryType, equals(CategoryType.expense));
      expect(decodedCategory.color, isNull);
      expect(decodedCategory.iconCodePoint,
          equals(FontAwesomeIcons.question.codePoint));
      expect(decodedCategory.icon, equals(FontAwesomeIcons.question));
      expect(decodedCategory.lastUsed, isNull);
      expect(decodedCategory.recordCount, equals(0));
      expect(decodedCategory.iconEmoji, isNull);
      expect(decodedCategory.isArchived, isFalse);
      expect(decodedCategory.sortOrder, equals(0));
    });

    test('should handle a Category with an emoji icon correctly', () {
      final testCategory = Category(
        'Emoji Category',
        iconEmoji: '🍣',
        categoryType: CategoryType.expense,
      );

      final map = testCategory.toMap();
      final decodedCategory = Category.fromMap(map);

      expect(decodedCategory.iconEmoji, equals('🍣'));
      expect(decodedCategory.iconCodePoint,
          isNull); // iconCodePoint should be null if emoji is present
      expect(decodedCategory.icon, isNull); // icon should be null too
      expect(decodedCategory.name, equals('Emoji Category'));
    });

    test('should handle a Category with a null color gracefully', () {
      final testCategory = Category('No Color', color: null);
      final map = testCategory.toMap();
      final decodedCategory = Category.fromMap(map);

      expect(map['color'], isNull);
      expect(decodedCategory.color, isNull);
    });
  });

  group('Category Constructor Logic', () {
    test('should set a default icon if iconCodePoint is null', () {
      final category = Category('Default Icon');
      expect(category.icon, equals(FontAwesomeIcons.question));
      expect(
          category.iconCodePoint, equals(FontAwesomeIcons.question.codePoint));
    });

    test('should set the correct icon when iconCodePoint is provided', () {
      final category = Category('Test',
          iconCodePoint: CategoryIcons.pro_category_icons[0].codePoint);
      expect(category.icon, equals(CategoryIcons.pro_category_icons[0]));
    });

    test('should set default categoryType to expense if not provided', () {
      final category = Category('Default Type');
      expect(category.categoryType, equals(CategoryType.expense));
    });

    test('should prefer iconEmoji over iconCodePoint', () {
      final category = Category(
        'Emoji Icon Test',
        iconEmoji: '🎉',
        iconCodePoint: FontAwesomeIcons.book.codePoint,
      );
      expect(category.iconEmoji, equals('🎉'));
      expect(category.icon, isNull);
      expect(category.iconCodePoint, FontAwesomeIcons.book.codePoint);
    });
  });

  group('Category Equality and Hashing', () {
    test('two categories with the same name and type should be equal', () {
      final category1 = Category('Rent', categoryType: CategoryType.expense);
      final category2 = Category('Rent', categoryType: CategoryType.expense);

      expect(category1, equals(category2));
      expect(category1.hashCode, equals(category2.hashCode));
    });

    test('categories with different names should not be equal', () {
      final category1 = Category('Rent', categoryType: CategoryType.expense);
      final category2 =
          Category('Groceries', categoryType: CategoryType.expense);

      expect(category1, isNot(equals(category2)));
    });

    test('categories with different types should not be equal', () {
      final category1 = Category('Salary', categoryType: CategoryType.income);
      final category2 = Category('Salary', categoryType: CategoryType.expense);

      expect(category1, isNot(equals(category2)));
    });

    test('categories are equal even if other properties are different', () {
      final category1 = Category(
        'Rent',
        categoryType: CategoryType.expense,
        color: Colors.red,
        recordCount: 5,
      );
      final category2 = Category(
        'Rent',
        categoryType: CategoryType.expense,
        color: Colors.blue,
        recordCount: 10,
      );

      expect(category1, equals(category2));
    });
  });
}
