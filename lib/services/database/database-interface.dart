import 'dart:async';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';


abstract class DatabaseInterface {

    /// DatabaseInterface is an interface that the database classes
    /// must implement. It contains basic CRUD methods for categories and records

    /// Category CRUD
    Future<List<Category>> getAllCategories();
    Future<List<Category>> getCategoriesByType(CategoryType categoryType);
    Future<Category> getCategory(String categoryName, CategoryType categoryType);
    Future<String> addCategory(Category category);
    Future<String> updateCategory(String existingCategoryName, CategoryType existingCategoryType, Category updatedCategory);
    Future<bool> deleteCategory(String name, CategoryType categoryType);
    
    /// Record CRUD
    Future<Record> getRecordById(String id);
    Future<void> deleteRecordById(String id);
    Future<String> addRecord(Record record);
    Future<String> updateRecordById(String recordId, Record newRecord);
    Future<List<Record>> getAllRecords();
    Future<List<Record>> getAllRecordsInInterval(DateTime from, DateTime to);
    Future<Record> getMatchingRecord(Record record);

    // Recurrent Records Patterns CRUD
    Future<List<RecurrentRecordPattern>> getRecurrentRecordPatterns();
    Future<RecurrentRecordPattern> getRecurrentRecordPattern(String recurrentPatternId);
    Future<void> addRecurrentRecordPattern(RecurrentRecordPattern recordPattern);
    Future<void> deleteRecurrentRecordPatternById(String recurrentPatternId);
    Future<void> updateRecordPatternById(String recurrentPatternId, RecurrentRecordPattern pattern);

        // Utils
    Future<void> deleteDatabase();
}