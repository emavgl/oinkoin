import 'package:in_app_purchase/in_app_purchase.dart';

import 'google_play_purchase_details.dart';

class QueryPurchaseDetailsResponse {
  QueryPurchaseDetailsResponse({required this.pastPurchases, this.error});

  final List<GooglePlayPurchaseDetails> pastPurchases;
  final IAPError? error;
}
