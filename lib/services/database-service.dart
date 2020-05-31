import 'dart:async';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';

abstract class DatabaseService {

    /// DatabaseService is an interface the database classes must implement.
    /// It contains all the method necessary to manage categories and records
    /// such as addCategory or getCategoryById.

    /// Category CRUD
    Future<Category> getCategoryById(int id);
    Future<List<Category>> getAllCategories();
    Future<List<Category>> getCategoriesByType(int categoryType);
    Future<Category> getCategoryByName(String categoryName);
    Future<int> addCategoryIfNotExists(Category category);
    Future<int> upsertCategory(Category category);
    Future<void> deleteCategoryById(int id);
    
    /// Record CRUD
    Future<Record> getRecordById(int id);
    Future<void> deleteRecordById(int id);
    Future<int> addRecord(Record record);
    Future<int> updateRecordById(int recordId, Record newRecord);
    Future<List<Record>> getAllRecords();
    Future<List<Record>> getAllRecordsInInterval(DateTime from, DateTime to);
}