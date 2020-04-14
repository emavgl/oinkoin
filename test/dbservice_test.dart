import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/movement.dart';
import 'package:piggybank/services/database-service.dart';
import 'package:piggybank/helpers/movements-generator.dart';

main() {
  group('database service test', () {

    test('fetch one category', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      Category category = new Category("testName");
      await DatabaseService.instance.addCategoryIfNotExists(category);
      Category retrievedCategory = await DatabaseService.instance.getCategoryById(1);
      expect(retrievedCategory.name, "testName");
      expect(retrievedCategory.id, 1);
    });

    test('fetch multiple categories', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      Category category1 = new Category("testName1");
      Category category2 = new Category("testName2");
      await DatabaseService.instance.addCategoryIfNotExists(category1);
      await DatabaseService.instance.addCategoryIfNotExists(category2);
      List<Category> retrievedCategories = await DatabaseService.instance.getAllCategories();
      expect(retrievedCategories.length, 2);
    });

    test('fetch one movement', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      Movement movement = MovementsGenerator.getRandomMovement(DateTime.now());
      await DatabaseService.instance.addMovement(movement);
      Movement retrievedMovement = await DatabaseService.instance.getMovementById(1);
      expect(retrievedMovement.value, movement.value);
      expect(retrievedMovement.dateTime.millisecondsSinceEpoch, movement.dateTime.millisecondsSinceEpoch);
      expect(retrievedMovement.id, 1);
    });

    test('fetch multiple movements', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      Movement movement = MovementsGenerator.getRandomMovement(DateTime.now());
      Movement movement2 = MovementsGenerator.getRandomMovement(DateTime.now().add(Duration(seconds: 5)));
      await DatabaseService.instance.addMovement(movement);
      await DatabaseService.instance.addMovement(movement2);
      List<Movement> retrievedMovements = await DatabaseService.instance.getAllMovements();
      expect(retrievedMovements.length, 2);
    });


    test('fetch multiple with Interval', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      Movement movement = MovementsGenerator.getRandomMovement(DateTime.parse("2020-04-10 13:00:00"));
      Movement movement2 = MovementsGenerator.getRandomMovement(DateTime.parse("2020-04-12 13:00:00"));
      Movement movement3 = MovementsGenerator.getRandomMovement(DateTime.parse("2020-05-10 13:00:00"));
      int movementId1 = await DatabaseService.instance.addMovement(movement);
      int movementId2 = await DatabaseService.instance.addMovement(movement2);
      int movementId3 = await DatabaseService.instance.addMovement(movement3);
      DateTime from = DateTime.parse("2020-04-01 00:00:00");
      DateTime to = DateTime.parse("2020-04-30 00:00:00");
      List<Movement> retrievedMovements = await DatabaseService.instance.getAllMovementsInInterval(from, to);
      expect(retrievedMovements.length, 2);
      expect(retrievedMovements[0].id != movementId3, true);
      expect(retrievedMovements[1].id != movementId3, true);
    });


    tearDown(() async {
      await DatabaseService.instance.deleteTables();
    });

  });
}
