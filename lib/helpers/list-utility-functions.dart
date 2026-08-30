/// Returns a new list with the item at [oldIndex] moved to [newIndex].
///
/// [newIndex] must already be adjusted for the removal of the item at
/// [oldIndex] - exactly what ReorderableListView's onReorderItem callback
/// provides (unlike the deprecated onReorder callback, which required the
/// caller to subtract 1 when moving an item downward).
List<T> moveListItem<T>(List<T> list, int oldIndex, int newIndex) {
  final result = List<T>.from(list);
  final moved = result.removeAt(oldIndex);
  result.insert(newIndex, moved);
  return result;
}
