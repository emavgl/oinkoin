import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:piggybank/auth/i18n/login-page.i18n.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';

import 'database-interface.dart';
import 'exceptions.dart';

// Import the firebase_core and cloud_firestore plugin
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseDatabase implements DatabaseInterface {

    FirebaseFirestore firestore;
    String user_id;

    static List<Category> getDefaultCategories() {
      List<Category> defaultCategories = [];
      defaultCategories.add(new Category("House".i18n,
          color: Category.colors[0],
          iconCodePoint: FontAwesomeIcons.home.codePoint,
          categoryType: CategoryType.expense
      ));
      defaultCategories.add(new Category("Transports".i18n,
          color: Category.colors[1],
          iconCodePoint: FontAwesomeIcons.bus.codePoint,
          categoryType: CategoryType.expense
      ));
      defaultCategories.add(new Category("Food".i18n,
          color: Category.colors[2],
          iconCodePoint: FontAwesomeIcons.hamburger.codePoint,
          categoryType: CategoryType.expense
      ));
      defaultCategories.add(new Category("Salary".i18n,
          color: Category.colors[3],
          iconCodePoint: FontAwesomeIcons.wallet.codePoint,
          categoryType: CategoryType.income
      ));
      return defaultCategories;
    }

    FirebaseDatabase(mode) {
      firestore = FirebaseFirestore.instance;
      user_id = FirebaseAuth.instance.currentUser.uid;

      // check if no categories are in, if so apply the standard ones
      getAllCategories().then((categories) async {
        if (categories.length == 0) {
          final defaultCategories = FirebaseDatabase.getDefaultCategories();
          for (var defaultCategory in defaultCategories) {
            await addCategory(defaultCategory);
          }
        }
      });
    }


    static List<Category> _categories = [
        Category("Rent", iconCodePoint: FontAwesomeIcons.home.codePoint, categoryType: CategoryType.expense),
        Category("Food", iconCodePoint: FontAwesomeIcons.hamburger.codePoint, categoryType: CategoryType.expense),
        Category("Salary", iconCodePoint: FontAwesomeIcons.wallet.codePoint, categoryType: CategoryType.income)
    ];

    static List<Record> _movements = [
        Record(-300, "April Rent", _categories[0], DateTime.parse("2020-04-02 10:30:00"), id: 1),
        Record(-300, "May Rent", _categories[0], DateTime.parse("2020-05-01 10:30:00"), id: 2),
        Record(-30, "Pizza", _categories[1], DateTime.parse("2020-05-01 09:30:00"), id: 3),
        Record(1700, "Salary", _categories[2], DateTime.parse("2020-05-02 09:30:00"), id: 4),
        Record(-30, "Restaurant", _categories[1], DateTime.parse("2020-05-02 10:30:00"), id: 5),
        Record(-60.5, "Groceries", _categories[1], DateTime.parse("2020-05-03 10:30:00"), id: 6),
    ];

    static List<Record> get movements => _movements;
    static List<Category> get categories => _categories;

    Future<List<Category>> getAllCategories() async {
      var result = await this.firestore.collection('user_data').doc(user_id).collection("user_categories").get();
      var docs = result.docs;
      List<Category> retrievedCategories = [];
      for (var doc in docs) {
        var data = doc.data();
        var category = Category.fromMap(data);
        retrievedCategories.add(category);
      }
      return retrievedCategories;
    }

    Future<List<Category>> getCategoriesByType(CategoryType categoryType) async {
        return Future<List<Category>>.value(_categories.where((x) => x.categoryType == categoryType).toList());
    }

    Future<Category> getCategory(String name, CategoryType categoryType) {
        var matching = _categories.where((x) => x.name == name && x.categoryType == categoryType).toList();
        return (matching.isEmpty) ? Future<Category>.value(null): Future<Category>.value(matching[0]);
    }

    Future<int> updateCategory(String existingCategoryName, CategoryType existingCategoryType, Category updatedCategory) async {
        var categoryWithTheSameName = await getCategory(existingCategoryName, existingCategoryType);
        if (categoryWithTheSameName == null) {
            throw NotFoundException();
        }
        var index = _categories.indexOf(categoryWithTheSameName);
        _categories[index] = updatedCategory;
        return Future<int>.value(index);
    }

    Future<void> deleteCategory(String categoryName, CategoryType categoryType) async {
        _categories.removeWhere((x) => x.name == categoryName && x.categoryType == categoryType);
    }

    Future<int> addRecord(Record movement) async {
        movement.id = _movements.length + 1;
        _movements.add(movement);
        return Future<int>.value(movement.id);
    }

    @override
    Future<String> addCategory(Category category) async {
      final result = await this.firestore.collection('user_data').doc(user_id).collection("user_categories").add(category.toJson());
      return result.id;
    }

    Future<List<Record>> getAllRecords() async {
        return Future<List<Record>>.value(_movements);
    }

    Future<List<Record>> getAllRecordsInInterval(DateTime from, DateTime to) async {
        List<Record> targetMovements = _movements.where((movement) =>
            movement.dateTime.isAfter(from) && movement.dateTime.isBefore(to)).toList();
        return Future<List<Record>>.value(targetMovements);
    }

    @override
    Future<Record> getRecordById(int id) {
      var matching = _movements.where((x) => x.id == id).toList();
      return (matching.isEmpty) ? Future<Record>.value(null): Future<Record>.value(matching[0]);
    }

    @override
    Future<Record> getMatchingRecord(Record record) async {
        var matching = _movements.where((x) => x.category == record.category && x.value == record.value && x.dateTime.isAtSameMomentAs(record.dateTime)).toList();
        return (matching.isEmpty) ? Future<Record>.value(null): Future<Record>.value(matching[0]);
    }

    @override
    Future<int> updateRecordById(int movementId, Record newMovement) async {
      var movementWithTheSameId = await getRecordById(movementId);
      if (movementWithTheSameId == null) {
          throw Exception("Movement ID `$movementId` does not exists.");
      }
      _movements[_movements.indexOf(movementWithTheSameId)] = newMovement;
      return movementId;
    }

    @override
    Future<void> deleteRecordById(int id) {
      _movements.removeWhere((x) => x.id == id);
    }

    @override
    Future<void> deleteDatabase() {
      _movements.clear();
      _categories.clear();
    }

  @override
  Future<void> addRecurrentRecordPattern(RecurrentRecordPattern recordPattern) {
    // TODO: implement addRecurrentRecordPattern
  }

  @override
  Future<void> deleteRecurrentRecordPatternById(String recurrentPatternId) {
    // TODO: implement deleteRecurrentRecordPatternById
  }

  @override
  Future<RecurrentRecordPattern> getRecurrentRecordPattern(String recurrentPatternId) {
    // TODO: implement getRecurrentRecordPattern
  }

  @override
  Future<List<RecurrentRecordPattern>> getRecurrentRecordPatterns() {
    // TODO: implement getRecurrentRecordPatterns
    return Future<List<RecurrentRecordPattern>>.value([]);
  }

  @override
  Future<void> updateRecordPatternById(String recurrentPatternId, RecurrentRecordPattern pattern) {
    // TODO: implement updateRecordPatternById
  }

}