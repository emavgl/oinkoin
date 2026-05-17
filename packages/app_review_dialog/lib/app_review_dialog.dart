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
///   supportWebsitePage: 'https://example.com/support',
///   minPositiveRating: 3.5,
/// );
/// ```
library app_review_dialog;

export 'src/app_review_dialog.dart'
    show AppReviewDialog, AppReviewDialogResult;
export 'src/app_review_localizations.dart'
    show AppReviewLocalizations;
