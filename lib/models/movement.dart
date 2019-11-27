import 'dart:math';

class Movement {
  static Random random = new Random();

  double value;
  String description;
  List<String> tags;

  Movement(this.value, this.description, this.tags);

  static Movement getMockMovement() {
    var mockValue = random.nextDouble() * 100;
    var mockDescription = "Random Description";
    var mockTag = "Mock Tag";
    List<String> mockTags = [mockTag];
    return new Movement(mockValue, mockDescription, mockTags);
  }
}