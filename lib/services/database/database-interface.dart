import 'dart:async';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';


abstract class DatabaseInterface {

    /// DatabaseInterface is an interface that the database classes
    /// must implement. It contains basic CRUD methods for categories and records

    /// Category CRUD
    Future<List<Category>> getAllCategories();
    Future<List<Category>> getCategoriesByType(int categoryType);
    Future<Category> getCategoryByName(String categoryName);
    Future<int> addCategory(Category category);
    Future<int> updateCategory(Category category);
    Future<void> deleteCategoryByName(String name);
    
    /// Record CRUD
    Future<Record> getRecordById(int id);
    Future<void> deleteRecordById(int id);
    Future<int> addRecord(Record record);
    Future<int> updateRecordById(int recordId, Record newRecord);
    Future<List<Record>> getAllRecords();
    Future<List<Record>> getAllRecordsInInterval(DateTime from, DateTime to);
}