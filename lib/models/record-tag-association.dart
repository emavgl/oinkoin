import 'package:piggybank/models/model.dart';

class RecordTagAssociation extends Model {
  /// Record id: a uuid for current backups, the string form of the integer id
  /// for backups written before the uuid migration.
  final String recordId;
  final String tagName;

  RecordTagAssociation({
    required this.recordId,
    required this.tagName,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      'record_id': recordId,
      'tag_name': tagName,
    };
  }

  static RecordTagAssociation fromMap(Map<String, dynamic> map) {
    return RecordTagAssociation(
      recordId: map['record_id'].toString(),
      tagName: map['tag_name'] as String,
    );
  }
}
