/// A beautiful in-app rating dialog for Flutter.
///
/// Shows a star rating prompt (with half-star granularity). When the user
/// gives a positive rating (>= [minPositiveRating]), they are encouraged
/// to leave a review in the app store. When the rating is lower, they are
/// invited to send feedback via email.
///
/// ## Usage
///
/// ```dart
/// await AppReviewDialog.show(
///   context,
///   supportEmail: 'hello@example.com',
///   storePackageName: 'com.example.myapp',
/// );
/// ```
///
/// No localisation delegate needed — the dialog detects the device locale
/// automatically, or you can pass an explicit [locale].
library app_review_dialog;

export 'src/app_review_dialog.dart'
    show AppReviewDialog, AppReviewDialogResult, AppReviewDialogAction;
