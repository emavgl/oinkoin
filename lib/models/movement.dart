import 'package:piggybank/models/tag.dart';

class Movement {

  double value;
  String description;
  List<Tag> tags;
  DateTime dateTime;

  Movement(this.value, this.description, this.tags, this.dateTime);

}