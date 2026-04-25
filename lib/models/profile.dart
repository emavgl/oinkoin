import 'model.dart';

class Profile extends Model {
  int? id;
  String name;
  bool isDefault;

  Profile(this.name, {this.id, this.isDefault = false});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'is_default': isDefault ? 1 : 0,
    };
  }

  static Profile fromMap(Map<String, dynamic> map) {
    return Profile(
      map['name'] as String,
      id: map['id'] as int?,
      isDefault: (map['is_default'] as int? ?? 0) == 1,
    );
  }
}
