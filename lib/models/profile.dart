import 'model.dart';

class Profile extends Model {
  int? id;
  String name;
  bool isDefault;
  int sortOrder;

  Profile(this.name, {this.id, this.isDefault = false, this.sortOrder = 0});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'is_default': isDefault ? 1 : 0,
      'sort_order': sortOrder,
    };
  }

  static Profile fromMap(Map<String, dynamic> map) {
    return Profile(
      map['name'] as String,
      id: map['id'] as int?,
      isDefault: (map['is_default'] as int? ?? 0) == 1,
      sortOrder: (map['sort_order'] as int?) ?? 0,
    );
  }
}
