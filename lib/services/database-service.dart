import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/movement.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:developer' as developer;

abstract class DatabaseService {
    /// DatabaseService is an interface the database classes must implement.
    /// It contains all the method necessary to manage categories and movements
    /// such as addCategory or getCategoryById.
    Future<Category> getCategoryById(int id);
    Future<List<Category>> getAllCategories();
    Future<Category> getCategoryByName(String categoryName);
    Future<int> addCategoryIfNotExists(Category category);
    Future<List<Category>> getCategoriesByType(int categoryType);
    void deleteCategoryById(int id);
    Future<int> upsertCategory(Category category);

    Future<Movement> getMovementById(int id);
    Future<int> addMovement(Movement movement);
    Future<int> updateMovementById(int movementId, Movement newMovement);
    Future<List<Movement>> getAllMovements();
    Future<List<Movement>> getAllMovementsInInterval(DateTime from, DateTime to);
}