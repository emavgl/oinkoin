import 'dart:math';
import 'dart:ui';

class Tag {

  static Random _random = new Random();

  String name;
  Color color;

  Tag(String name) {
    this.name = name;
    var _r = _random.nextInt(255);
    var _g = _random.nextInt(255);
    var _b = _random.nextInt(255);
    this.color = Color.fromARGB(255, _r, _g, _b);
  }

}