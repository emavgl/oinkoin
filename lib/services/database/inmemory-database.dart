import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';

import 'database-interface.dart';
import 'exceptions.dart';


class InMemoryDatabase implements DatabaseInterface {

    /// InMemoryDatabase is an implementation of DatabaseService that runs in memory.
    /// All this methods are implemented using operations on Lists.
    /// InMemoryDatabase is intended for debug/testing purposes.

    static List<Category> _categories = [
        Category("Rent", iconCodePoint: FontAwesomeIcons.home.codePoint, categoryType: CategoryType.expense),
        Category("Food", iconCodePoint: FontAwesomeIcons.hamburger.codePoint, categoryType: CategoryType.expense),
        Category("Salary", iconCodePoint: FontAwesomeIcons.wallet.codePoint, categoryType: CategoryType.income)
    ];

    static List<Record> _movements = [
        Record(-300, "April Rent", _categories[0], DateTime.parse("2020-04-02 10:30:00"), id: "1"),
        Record(-300, "May Rent", _categories[0], DateTime.parse("2020-05-01 10:30:00"), id: "2"),
        Record(-30, "Pizza", _categories[1], DateTime.parse("2020-05-01 09:30:00"), id: "3"),
        Record(1700, "Salary", _categories[2], DateTime.parse("2020-05-02 09:30:00"), id: "4"),
        Record(-30, "Restaurant", _categories[1], DateTime.parse("2020-05-02 10:30:00"), id: "5"),
        Record(-60.5, "Groceries", _categories[1], DateTime.parse("2020-05-03 10:30:00"), id: "6"),
    ];

    static List<Record> get movements => _movements;
    static List<Category> get categories => _categories;

    Future<List<Category>> getAllCategories() async {
        return Future<List<Category>>.value(_categories);
    }

    Future<List<Category>> getCategoriesByType(CategoryType categoryType) async {
        return Future<List<Category>>.value(_categories.where((x) => x.categoryType == categoryType).toList());
    }

    Future<Category> getCategory(String name, CategoryType categoryType) {
        var matching = _categories.where((x) => x.name == name && x.categoryType == categoryType).toList();
        return (matching.isEmpty) ? Future<Category>.value(null): Future<Category>.value(matching[0]);
    }

    Future<String> updateCategory(String existingCategoryName, CategoryType existingCategoryType, Category updatedCategory) async {
        var categoryWithTheSameName = await getCategory(existingCategoryName, existingCategoryType);
        if (categoryWithTheSameName == null) {
            throw NotFoundException();
        }
        var index = _categories.indexOf(categoryWithTheSameName);
        _categories[index] = updatedCategory;
        return Future<String>.value(index.toString());
    }

    Future<bool> deleteCategory(String categoryName, CategoryType categoryType) async {
        if (_categories.where((x) => x.name == categoryName && x.categoryType == categoryType).isEmpty) {
          return Future<bool>.value(false);
        } else {
          _categories.removeWhere((x) => x.name == categoryName && x.categoryType == categoryType);
          return Future<bool>.value(true);
        }
    }

    Future<String> addRecord(Record movement) async {
        movement.id = (_movements.length + 1).toString();
        _movements.add(movement);
        return Future<String>.value(movement.id.toString());
    }

    @override
    Future<String> addCategory(Category category) async {
        Category foundCategory = await this.getCategory(category.name, category.categoryType);
        if (foundCategory != null) {
            throw ElementAlreadyExists();
        }
        _categories.add(category);
        return Future<String>.value((_categories.length - 1).toString());
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
    Future<Record> getRecordById(String id) {
      var matching = _movements.where((x) => x.id == id).toList();
      return (matching.isEmpty) ? Future<Record>.value(null): Future<Record>.value(matching[0]);
    }

    @override
    Future<Record> getMatchingRecord(Record record) async {
        var matching = _movements.where((x) => x.category == record.category && x.value == record.value && x.dateTime.isAtSameMomentAs(record.dateTime)).toList();
        return (matching.isEmpty) ? Future<Record>.value(null): Future<Record>.value(matching[0]);
    }

    @override
    Future<String> updateRecordById(String movementId, Record newMovement) async {
      var movementWithTheSameId = await getRecordById(movementId);
      if (movementWithTheSameId == null) {
          throw Exception("Movement ID `$movementId` does not exists.");
      }
      _movements[_movements.indexOf(movementWithTheSameId)] = newMovement;
      return movementId;
    }

    @override
    Future<void> deleteRecordById(String id) {
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
    throw UnimplementedError();
  }

  @override
  Future<void> deleteRecurrentRecordPatternById(String recurrentPatternId) {
    // TODO: implement deleteRecurrentRecordPatternById
    throw UnimplementedError();
  }

  @override
  Future<RecurrentRecordPattern> getRecurrentRecordPattern(String recurrentPatternId) {
    // TODO: implement getRecurrentRecordPattern
    throw UnimplementedError();
  }

  @override
  Future<List<RecurrentRecordPattern>> getRecurrentRecordPatterns() {
    // TODO: implement getRecurrentRecordPatterns
    throw UnimplementedError();
  }

  @override
  Future<void> updateRecordPatternById(String recurrentPatternId, RecurrentRecordPattern pattern) {
    // TODO: implement updateRecordPatternById
    throw UnimplementedError();
  }

}