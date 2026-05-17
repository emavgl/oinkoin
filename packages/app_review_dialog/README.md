# App Review Dialog

A beautiful, localised in-app rating dialog for Flutter apps — inspired by
Android's native in-app review flow.

## Features

- **Star rating** with half-star granularity (tap on a star to select)
- **Two paths**: positive ratings → "Rate in store" + "Support"; lower ratings → "Send feedback"
- **Smooth animations** on stars, dialog transitions, and between steps
- **Fully localised** in 21 languages
- **All strings overridable** per call
- **Configurable**: `supportEmail` (mandatory), `supportWebsitePage` (optional), `minPositiveRating`
- **Theme-aware** — follows Material color scheme

## Screenshots (conceptual)

```
┌──────────────────────┐   ┌──────────────────────┐
│   Enjoy the app?     │   │      Thank you!       │
│                      │   │                        │
│   ★ ★ ★ ☆ ☆         │   │  Rate in store  [btn] │
│   Tap to rate        │   │  Support        [btn] │
└──────────────────────┘   └──────────────────────┘
```

## Usage

```dart
import 'package:app_review_dialog/app_review_dialog.dart';

final result = await AppReviewDialog.show(
  context,
  supportEmail: 'hello@example.com',
  supportWebsitePage: 'https://example.com/support',
  minPositiveRating: 3.5,
);

if (result != null && result.action == AppReviewDialogAction.ratedPositive) {
  // Open the Play Store / App Store for the user to leave a review
  _openStoreForReview();
}
```

### Customising strings

Every string can be overridden per invocation:

```dart
AppReviewDialog.show(
  context,
  supportEmail: 'hello@example.com',
  title: 'Enjoying OurApp?',
  positiveTitle: 'Awesome! 🎉',
  // ... all other strings
);
```

## Setup

Add the delegate to your `MaterialApp`:

```dart
import 'package:app_review_dialog/app_review_dialog.dart';

MaterialApp(
  localizationsDelegates: [
    appReviewLocalizationsDelegate,
    // ... your other delegates
  ],
  supportedLocales: supportedAppReviewLocales,
  // ...
);
```

## Supported locales

`ar` · `ca` · `da` · `de` · `el` · `en` · `es` · `fr` · `hr` · `it` · `ja` · `or` · `pl` · `pt` · `pt-BR` · `pt-PT` · `ru` · `ta` · `tr` · `uk` · `vec` · `zh`

## License

MIT
