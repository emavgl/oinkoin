import 'dart:math';
import 'dart:ui';
import 'package:piggybank/models/model.dart';

class Category extends Model {

  static Random _random = new Random();

  int id;
  String name;
  Color color;

  Category(String name, {this.color, this.id}) {
    this.name = name;
    if (this.color == null) {
      var _r = _random.nextInt(255);
      var _g = _random.nextInt(255);
      var _b = _random.nextInt(255);
      this.color = Color.fromARGB(255, _r, _g, _b);
    }
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      'name': name,
      'color': color.alpha.toString() + ":" + color.red.toString() + ":"
          + color.green.toString() + ":" + color.blue.toString()
    };

    if (this.id != null) { map['id'] = this.id; }
    return map;
  }

  static Category fromMap(Map<String, dynamic> map) {
    String serializedColor = map["color"] as String;
    int category_id = map["category_id"] != null ?
                      map["category_id"] as int : map["id"] as int;
    List<int> colorComponents = serializedColor.split(":").map(int.parse).toList();
    return Category(
      map["name"],
      color: Color.fromARGB(colorComponents[0], colorComponents[1], colorComponents[2], colorComponents[3]),
      id: category_id
    );
  }

}