import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:piggybank/helpers/categories-generator.dart';
import 'package:piggybank/helpers/day-movement-generator.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/movements-per-day.dart';

class MovementsInMemoryDatabase {

    static List<MovementsPerDay> _movementsDays = DayMovementGenerator.getRandomDayMovements(quantity: 20);
    static List<Category> _categories = [
        Category("Rent", iconCodePoint: FontAwesomeIcons.home.codePoint, categoryType: 0),
        Category("Food", iconCodePoint: FontAwesomeIcons.hamburger.codePoint, categoryType: 0),
        Category("Salary", iconCodePoint: FontAwesomeIcons.wallet.codePoint, categoryType: 1)
    ];
    static List<MovementsPerDay> get movementsDays => _movementsDays;
    static List<Category> get categories => _categories;

    static Future<Category> getCategoryById(int id) {
        var matching = _categories.where((x) => x.id == id).toList();
        return (matching.isEmpty) ? Future<Category>.value(null): Future<Category>.value(matching[0]);
    }

    static Future<List<Category>> getAllCategories() async {
        return Future<List<Category>>.value(_categories);
    }

    static Future<List<Category>> getCategoriesByType(int categoryType) async {
        return Future<List<Category>>.value(_categories.where((x) => x.categoryType == categoryType).toList());
    }

    static Future<Category> getCategoryByName(String name) {
        var matching = _categories.where((x) => x.name == name).toList();
        return (matching.isEmpty) ? Future<Category>.value(null): Future<Category>.value(matching[0]);
    }

    static Future<int> upsertCategory(Category category) async {
        var existingCategory = await getCategoryByName(category.name);
        if (existingCategory != null) {
            var indexOfExistingCategory = _categories.indexOf(existingCategory);
            category.id = existingCategory.id;
            _categories[indexOfExistingCategory] = category;
            return existingCategory.id;
        } else {
            category.id = _categories.length + 1;
            _categories.add(category);
            return Future<int>.value(category.id);
        }
    }

    static void deleteCategoryById(int categoryId) async {
        _categories.removeWhere((x) => x.id == categoryId);
    }



}