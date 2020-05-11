import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/movement.dart';
import 'package:sqflite_common/sqlite_api.dart';

import 'database-service.dart';

class InMemoryDatabase implements DatabaseService {

    static List<Category> _categories = [
        Category("Rent", iconCodePoint: FontAwesomeIcons.home.codePoint, categoryType: 0, id: 1),
        Category("Food", iconCodePoint: FontAwesomeIcons.hamburger.codePoint, categoryType: 0, id: 2),
        Category("Salary", iconCodePoint: FontAwesomeIcons.wallet.codePoint, categoryType: 1, id: 3)
    ];

    static List<Movement> _movements = [
        Movement(-300, "Rent", _categories[0], DateTime.parse("2020-05-01 10:30:00"), id: 1),
        Movement(-30, "Pizza", _categories[1], DateTime.parse("2020-05-01 09:30:00"), id: 2),
        Movement(1700, "Salary", _categories[2], DateTime.parse("2020-05-02 09:30:00"), id: 3),
        Movement(-30, "Restaurant", _categories[1], DateTime.parse("2020-05-02 10:30:00"), id: 4),
        Movement(-60.5, "Groceries", _categories[1], DateTime.parse("2020-05-03 10:30:00"), id: 5),
    ];

    static List<Movement> get movements => _movements;
    static List<Category> get categories => _categories;

    Future<Category> getCategoryById(int id) {
        var matching = _categories.where((x) => x.id == id).toList();
        return (matching.isEmpty) ? Future<Category>.value(null): Future<Category>.value(matching[0]);
    }

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

    Future<int> upsertCategory(Category category) async {
        var categoryWithTheSameId = await getCategoryById(category.id);
        if (categoryWithTheSameId != null) {
            // I'm updating an existing category
            _categories[_categories.indexOf(categoryWithTheSameId)] = category;
        } else {
            // no category with the same id exists, adding new category
            // new category can have the same name of another one
            // if so, update the category with the same name, keeping the id
            // otherwise, add new category assigning the id
            var categoryWithTheSameName = await getCategoryByName(category.name);
            if (categoryWithTheSameName != null) {
                var indexOfExistingCategory = _categories.indexOf(categoryWithTheSameName);
                category.id = categoryWithTheSameName.id;
                _categories[indexOfExistingCategory] = category;
            } else {
                category.id = _categories.length + 1;
                _categories.add(category);
            }
        }
        return Future<int>.value(category.id);
    }

    void deleteCategoryById(int categoryId) async {
        _categories.removeWhere((x) => x.id == categoryId);
    }

    Future<int> addMovement(Movement movement) async {
        movement.id = _movements.length + 1;
        _movements.add(movement);
        return Future<int>.value(movement.id);
    }

    Future<int> addCategory(Category category) async {
      category.id = _categories.length + 1;
      _categories.add(category);
      return Future<int>.value(category.id);
    }

    Future<List<Movement>> getAllMovements() async {
        return Future<List<Movement>>.value(_movements);
    }

    Future<List<Movement>> getAllMovementsInInterval(DateTime from, DateTime to) async {
        List<Movement> targetMovements = _movements.where((movement) =>
            movement.dateTime.isAfter(from) && movement.dateTime.isBefore(to)).toList();
        return Future<List<Movement>>.value(targetMovements);
    }

    @override
    Future<int> addCategoryIfNotExists(Category category) async {
      Category foundCategory = await this.getCategoryById(category.id);
      if (foundCategory == null) {
        return await addCategory(category);
      }
    }

    @override
    Future<Movement> getMovementById(int id) {
      var matching = _movements.where((x) => x.id == id).toList();
      return (matching.isEmpty) ? Future<Movement>.value(null): Future<Movement>.value(matching[0]);
    }

}