import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';

import 'database-interface.dart';
import 'exceptions.dart';


class InMemoryDatabase implements DatabaseInterface {

    /// InMemoryDatabase is an implementation of DatabaseService that runs in memory.
    /// All this methods are implemented using operations on Lists.
    /// InMemoryDatabase is intended for debug/testing purposes.

    static List<Category> _categories = [
        Category("Rent", iconCodePoint: FontAwesomeIcons.home.codePoint, categoryType: 0),
        Category("Food", iconCodePoint: FontAwesomeIcons.hamburger.codePoint, categoryType: 0),
        Category("Salary", iconCodePoint: FontAwesomeIcons.wallet.codePoint, categoryType: 1)
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
        return Future<List<Category>>.value(_categories);
    }

    Future<List<Category>> getCategoriesByType(int categoryType) async {
        return Future<List<Category>>.value(_categories.where((x) => x.categoryType == categoryType).toList());
    }

    Future<Category> getCategoryByName(String name) {
        var matching = _categories.where((x) => x.name == name).toList();
        return (matching.isEmpty) ? Future<Category>.value(null): Future<Category>.value(matching[0]);
    }

    Future<int> updateCategory(Category category) async {
        var categoryWithTheSameName = await getCategoryByName(category.name);
        if (categoryWithTheSameName == null) {
            throw NotFoundException();
        }
        var index = _categories.indexOf(categoryWithTheSameName);
        _categories[index] = category;
        return Future<int>.value(index);
    }

    Future<void> deleteCategoryByName(String categoryName) async {
        _categories.removeWhere((x) => x.name == categoryName);
    }

    Future<int> addRecord(Record movement) async {
        movement.id = _movements.length + 1;
        _movements.add(movement);
        return Future<int>.value(movement.id);
    }

    @override
    Future<int> addCategory(Category category) async {
        Category foundCategory = await this.getCategoryByName(category.name);
        if (foundCategory != null) {
            throw ElementAlreadyExists();
        }
        _categories.add(category);
        return Future<int>.value(_categories.length - 1);
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

}