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
    Future<int> addCategory(Category category);
    Future<int> updateCategory(String existingCategoryName, CategoryType existingCategoryType, Category updatedCategory);
    Future<void> deleteCategory(String name, CategoryType categoryType);
    
    /// Record CRUD
    Future<Record> getRecordById(int id);
    Future<void> deleteRecordById(int id);
    Future<int> addRecord(Record record);
    Future<int> updateRecordById(int recordId, Record newRecord);
    Future<List<Record>> getAllRecords();
    Future<List<Record>> getAllRecordsInInterval(DateTime from, DateTime to);
    Future<Record> getMatchingRecord(Record record);

    // Recurrent Records Patterns CRD
    Future<List<RecurrentRecordPattern>> getRecurrentRecordPatterns();
    Future<RecurrentRecordPattern> getRecurrentRecordPattern(String recurrentPatternId);
    Future<void> addRecurrentRecordPattern(RecurrentRecordPattern recordPattern);
    Future<void> deleteRecurrentRecordPatternById(String recurrentPatternId);

    // Utils
    Future<void> deleteDatabase();
}