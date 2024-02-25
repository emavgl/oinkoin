abstract class Model {
  /// All the Models that have to be stored in the SQLite3 database have to implement
  /// the following functions to help with the serialization and deserialization.

  static fromMap() {}
  toMap() {}
  Map toJson() => toMap();
  Map fromJson() => fromMap();
}
