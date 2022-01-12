import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:piggybank/auth/i18n/login-page.i18n.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';
import 'package:collection/collection.dart';

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

    static List<Record> getDebugRecords() {
      var _categories = getDefaultCategories();
      return [
        Record(-300, "April Rent", _categories[0], DateTime.parse("2020-04-02 10:30:00"), id: "1"),
        Record(-300, "May Rent", _categories[0], DateTime.parse("2020-05-01 10:30:00"), id: "2"),
        Record(-30, "Pizza", _categories[1], DateTime.parse("2020-05-01 09:30:00"), id: "3"),
        Record(1700, "Salary", _categories[2], DateTime.parse("2020-05-02 09:30:00"), id: "4"),
        Record(-30, "Restaurant", _categories[1], DateTime.parse("2020-05-02 10:30:00"), id: "5"),
        Record(-60.5, "Groceries", _categories[1], DateTime.parse("2020-05-03 10:30:00"), id: "6"),
      ];
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

    // Category Operations

    Future<List<Category>> getAllCategories() async {
        var result = await this.firestore.collection('user_data').doc(user_id).collection("user_categories").get();
        var docs = result.docs;
        List<Category> retrievedCategories = [];
        for (var doc in docs) {
          var data = doc.data();
          data.putIfAbsent("id", () => doc.id);
          var category = Category.fromMap(data);
          retrievedCategories.add(category);
        }
        return retrievedCategories;
    }

    Future<List<Category>> getCategoriesByType(CategoryType categoryType) async {
        var result = await this.firestore.collection('user_data')
            .doc(user_id)
            .collection("user_categories")
            .where("category_type", isEqualTo: categoryType.index)
            .get();
        var docs = result.docs;
        List<Category> retrievedCategories = [];
        for (var doc in docs) {
          var data = doc.data();
          data.putIfAbsent("id", () => doc.id);
          var category = Category.fromMap(data);
          retrievedCategories.add(category);
        }
        return retrievedCategories;
    }

    Future<Category> getCategory(String name, CategoryType categoryType) async {
        var result = await this.firestore.collection('user_data')
            .doc(user_id)
            .collection("user_categories")
            .where("category_type", isEqualTo: categoryType.index)
            .where("name", isEqualTo: name)
            .get();
        var docs = result.docs;
        List<Category> retrievedCategories = [];
        for (var doc in docs) {
          var data = doc.data();
          data.putIfAbsent("id", () => doc.id);
          var category = Category.fromMap(data);
          retrievedCategories.add(category);
        }
        return retrievedCategories.firstOrNull;
    }

    Future<String> updateCategory(String existingCategoryName, CategoryType existingCategoryType, Category updatedCategory) async {
      var existingCategory = await getCategory(existingCategoryName, existingCategoryType);
      if (existingCategory == null) {
        return null; // element does not exists
      } else {
        updatedCategory.id = existingCategory.id;
        await this.firestore.collection('user_data')
            .doc(user_id)
            .collection("user_categories")
            .doc(existingCategory.id)
            .update(updatedCategory.toJson());
        return updatedCategory.id;
      }
    }

    Future<bool> deleteCategory(String categoryName, CategoryType categoryType) async {
        var category = await getCategory(categoryName, categoryType);
        if (category == null) {
          return false;
        }
        // Delete the category
        await this.firestore.collection('user_data')
            .doc(user_id)
            .collection("user_categories")
            .doc(category.id)
            .delete();
        // Delete related records
        var reletedRecords = await this.firestore.collection('user_data')
            .doc(user_id)
            .collection("user_records")
            .where("category_name", isEqualTo: categoryName)
            .where("category_type", isEqualTo: categoryType.index)
            .get();
        for (var r in reletedRecords.docs) {
          String recordIdToBeDeleted = r.id;
          await this.firestore.collection('user_data')
              .doc(user_id)
              .collection("user_records")
              .doc(recordIdToBeDeleted)
              .delete();
        }
        // TODO: delete related recurrent records
    }

    @override
    Future<String> addCategory(Category category) async {
      final result = await this.firestore.collection('user_data').doc(user_id).collection("user_categories").add(category.toJson());
      return result.id;
    }


    // Records Operations

    Future<String> addRecord(Record record) async {
      final result = await this.firestore.collection('user_data').doc(user_id).collection("user_records").add(record.toJson());
      return result.id;
    }

    Future<List<Record>> getAllRecords() async {
        var result = await this.firestore.collection('user_data').doc(user_id).collection("user_records").get();
        var docs = result.docs;
        List<Record> records = [];
        for (var doc in docs) {
          var data = doc.data();
          data.putIfAbsent("id", () => doc.id);
          data["category"] = await getCategory(data['category_name'], CategoryType.values[data['category_type']]);
          var record = Record.fromMap(data);
          records.add(record);
        }
        return records;
    }

    Future<List<Record>> getAllRecordsInInterval(DateTime from, DateTime to) async {
      final from_unix = from.millisecondsSinceEpoch;
      final to_unix = to.millisecondsSinceEpoch;
      var result = await this.firestore
          .collection('user_data')
          .doc(user_id)
          .collection("user_records")
          .where("datetime", isGreaterThanOrEqualTo: from_unix)
          .where("datetime", isLessThanOrEqualTo: to_unix)
          .get();
      var docs = result.docs;
      List<Record> records = [];
      for (var doc in docs) {
        var data = doc.data();
        data.putIfAbsent("id", () => doc.id);
        data["category"] = await getCategory(data['category_name'], CategoryType.values[data['category_type']]);
        var record = Record.fromMap(data);
        records.add(record);
      }
      return records;
    }

    Future<Record> getRecordById(String recordId) async {
      var doc = await this.firestore.collection('user_data')
          .doc(user_id)
          .collection("user_records")
          .doc(recordId)
          .get();
      if (doc == null) return null;
      var data = doc.data();
      data["category"] = await getCategory(data['category_name'], CategoryType.values[data['category_type']]);
      data.putIfAbsent("id", () => doc.id);
      return Record.fromMap(data);
    }

    @override
    Future<Record> getMatchingRecord(Record record) async {
        var result = await this.firestore
            .collection('user_data')
            .doc(user_id)
            .collection("user_records")
            .where("datetime", isEqualTo: record.dateTime.millisecondsSinceEpoch)
            .where("category_name", isEqualTo: record.category.name)
            .where("category_type", isEqualTo: record.category.categoryType.index)
            .where("value", isEqualTo: record.value)
            .get();
        var docs = result.docs;
        List<Record> retrievedRecords = [];
        for (var doc in docs) {
          var data = doc.data();
          data.putIfAbsent("id", () => doc.id);
          data["category"] = await getCategory(data['category_name'], CategoryType.values[data['category_type']]);
          var record = Record.fromMap(data);
          retrievedRecords.add(record);
        }
        return retrievedRecords.firstOrNull;
    }

    @override
    Future<String> updateRecordById(String movementId, Record newMovement) async {
      var existingRecord = await getRecordById(movementId);
      if (existingRecord == null) {
        return null; // element does not exists
      } else {
        await this.firestore.collection('user_data')
            .doc(user_id)
            .collection("user_records")
            .doc(movementId)
            .update(newMovement.toJson());
        return movementId;
      }
    }

    @override
    Future<void> deleteRecordById(String recordId) async {
      await this.firestore.collection('user_data')
          .doc(user_id)
          .collection("user_records")
          .doc(recordId)
          .delete();
    }

    @override
    Future<void> deleteDatabase() async {
      await this.firestore.collection('user_data')
          .doc(user_id)
          .delete();
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