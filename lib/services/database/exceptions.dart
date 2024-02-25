class NotFoundException implements Exception {
  String? cause;
  NotFoundException({this.cause});
}

class ElementAlreadyExists implements Exception {
  String? cause;
  ElementAlreadyExists({this.cause});
}
