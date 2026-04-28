/// Represents the user-configured mapping of CSV columns to Oinkoin record fields.
///
/// Each field holds the CSV column header name (or null if unmapped).
class CsvImportMapping {
  String? titleColumn;
  String? valueColumn;
  String? datetimeColumn;
  String? categoryColumn;
  String? descriptionColumn;
  String? tagsColumn;
  String? walletColumn;

  CsvImportMapping({
    this.titleColumn,
    this.valueColumn,
    this.datetimeColumn,
    this.categoryColumn,
    this.descriptionColumn,
    this.tagsColumn,
    this.walletColumn,
  });

  /// All column-to-field entries as a map, keyed by field name.
  Map<String, String?> get asFieldMap => {
        'title': titleColumn,
        'value': valueColumn,
        'datetime': datetimeColumn,
        'category_name': categoryColumn,
        'description': descriptionColumn,
        'tags': tagsColumn,
        'wallet': walletColumn,
      };

  /// Returns the mapped column for a field name, or null.
  String? columnFor(String field) => asFieldMap[field];

  /// Updates the mapping for a given field.
  void setColumn(String field, String? column) {
    switch (field) {
      case 'title':
        titleColumn = column;
        break;
      case 'value':
        valueColumn = column;
        break;
      case 'datetime':
        datetimeColumn = column;
        break;
      case 'category_name':
        categoryColumn = column;
        break;
      case 'description':
        descriptionColumn = column;
        break;
      case 'tags':
        tagsColumn = column;
        break;
      case 'wallet':
        walletColumn = column;
        break;
    }
  }

  /// Whether the minimum required fields (value + datetime) are mapped.
  bool get hasMinimumMapping => valueColumn != null && datetimeColumn != null;

  /// Field keys in display order.
  static const List<String> fieldOrder = [
    'title',
    'value',
    'datetime',
    'category_name',
    'description',
    'tags',
    'wallet',
  ];

  /// Human-readable names for each field.
  static const Map<String, String> fieldLabels = {
    'title': 'Title',
    'value': 'Amount',
    'datetime': 'Date/Time',
    'category_name': 'Category',
    'description': 'Description',
    'tags': 'Tags',
    'wallet': 'Wallet',
  };

  /// Whether every field is unmapped.
  bool get isEmpty =>
      titleColumn == null &&
      valueColumn == null &&
      datetimeColumn == null &&
      categoryColumn == null &&
      descriptionColumn == null &&
      tagsColumn == null &&
      walletColumn == null;

  Map<String, dynamic> toJson() => asFieldMap;

  factory CsvImportMapping.fromJson(Map<String, dynamic> json) {
    return CsvImportMapping(
      titleColumn: json['title'] as String?,
      valueColumn: json['value'] as String?,
      datetimeColumn: json['datetime'] as String?,
      categoryColumn: json['category_name'] as String?,
      descriptionColumn: json['description'] as String?,
      tagsColumn: json['tags'] as String?,
      walletColumn: json['wallet'] as String?,
    );
  }

  @override
  String toString() => 'CsvImportMapping($asFieldMap)';
}
