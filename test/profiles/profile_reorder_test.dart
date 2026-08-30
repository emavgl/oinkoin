import 'package:flutter_test/flutter_test.dart';
import 'package:piggybank/profiles/profiles-page.dart';

void main() {
  group('moveListItem', () {
    test(
        'moving the first of two items below the second '
        '(reported regression: this used to be a no-op)', () {
      // ReorderableListView.onReorderItem already adjusts newIndex for the
      // removal of the item at oldIndex, so moving index 0 to "after index 1"
      // in a 2-item list is reported as newIndex: 1, not 2.
      final result = moveListItem(['A', 'B'], 0, 1);
      expect(result, ['B', 'A']);
    });

    test('moving the second of two items above the first', () {
      final result = moveListItem(['A', 'B'], 1, 0);
      expect(result, ['B', 'A']);
    });

    test('moving an item to the same position is a no-op', () {
      final result = moveListItem(['A', 'B', 'C'], 1, 1);
      expect(result, ['A', 'B', 'C']);
    });

    test('moving the first item to the end of a longer list', () {
      final result = moveListItem(['A', 'B', 'C', 'D'], 0, 3);
      expect(result, ['B', 'C', 'D', 'A']);
    });

    test('moving the last item to the start of a longer list', () {
      final result = moveListItem(['A', 'B', 'C', 'D'], 3, 0);
      expect(result, ['D', 'A', 'B', 'C']);
    });

    test('does not mutate the original list', () {
      final original = ['A', 'B'];
      moveListItem(original, 0, 1);
      expect(original, ['A', 'B']);
    });
  });
}
