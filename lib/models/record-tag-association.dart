import 'package:piggybank/models/model.dart';

class RecordTagAssociation extends Model {
  final int recordId;
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
      recordId: map['record_id'] as int,
      tagName: map['tag_name'] as String,
    );
  }
}
