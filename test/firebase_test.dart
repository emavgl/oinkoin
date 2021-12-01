import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:piggybank/helpers/records-generator.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/recurrent-period.dart';
import 'package:piggybank/models/recurrent-record-pattern.dart';
import 'package:piggybank/services/database/firebase-database.dart';
import 'package:firebase_core/firebase_core.dart';


main() {
  group('firestore test', () {

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      FirebaseFirestore.instance.settings = const Settings(
          host: 'localhost:8080', sslEnabled: false, persistenceEnabled: false);
    });

    test('add a new category', () async {
      Category category1 = new Category("testName1");
      final firebaseDatabase = FirebaseDatabase("debug");
      String new_categoryId = await firebaseDatabase.addCategory(category1);
      expect(new_categoryId != null, true);
    });

  });
}
