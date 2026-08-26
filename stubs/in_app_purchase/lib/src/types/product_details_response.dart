import 'product_details.dart';

class ProductDetailsResponse {
  ProductDetailsResponse({
    required this.productDetails,
    required this.notFoundIDs,
    this.error,
  });

  final List<ProductDetails> productDetails;
  final List<String> notFoundIDs;
  final dynamic error;
}
