/// No-op stub for F-Droid builds.
///
/// Exports the same public API surface as the real `in_app_purchase` package
/// so that app code compiles, but with empty implementations.  The real
/// package is swapped in for Play Store / GitHub builds by the CI script.

export 'src/in_app_purchase.dart';
export 'src/types/product_details.dart';
export 'src/types/product_details_response.dart';
export 'src/types/purchase_details.dart';
export 'src/types/purchase_param.dart';
export 'src/types/purchase_status.dart';
export 'src/types/purchase_verification_data.dart';
export 'src/errors/iap_error.dart';
export 'src/errors/in_app_purchase_exception.dart';
