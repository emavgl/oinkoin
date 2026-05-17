# App Review Dialog

A beautiful, fully localised in-app rating dialog for Flutter. Works on every
platform — **Android, iOS, web, Linux, Windows, and macOS** — with zero
platform-specific code in your app.

## Why this instead of `in_app_review`?

| | `in_app_review` | `app_review_dialog` |
|---|---|---|
| **Platforms** | Android + iOS only | Everywhere |
| **When you can show it** | Platform decides (quotas, cool-downs) | **You** decide |
| **Negative ratings** | Lost forever | Captured as feedback email |
| **Look & feel** | Native, not customisable | Themed, every string overridable |
| **Extra actions** | None | Rating + Support/Contribute link |
| **22 languages** | Depends on OS | Built-in |

The native in‑app review API is great for frictionless ratings — but it gives you
**no feedback from unhappy users** and **no control over timing**. This package
complements it: show it *after* the native dialog, or use it where the native
API isn't available (web, desktop).

## Quick start

```dart
import 'package:app_review_dialog/app_review_dialog.dart';

final result = await AppReviewDialog.show(
  context,
  supportEmail: 'hello@myapp.com',
  storePackageName: 'com.example.myapp',
);

print('Rating: ${result?.rating}, Action: ${result?.action}');
```

## How it works

1. User sees **"How much do you enjoy the app?"** with 5 tappable stars
2. Taps a star → that star and all before it fill with a bounce animation
3. Taps **Continue**
4. **≥ minPositiveRating (default 4):** "Thank you!" → Rate in store + Support & Contribute
5. **< minPositiveRating:** "How can we make it better?" → Send us an email

### Visual flow

```
 ┌─────────────────────────┐     ┌─────────────────────────┐
 │   Enjoy the app?        │     │      Thank you! ♥        │
 │                         │     │                          │
 │   ★ ★ ★ ☆ ☆            │     │  ┌────────────────────┐  │
 │                         │     │  │  Rate in store     │  │
 │  [Cancel]   [Continue]  │     │  └────────────────────┘  │
 └─────────────────────────┘     │  ┌────────────────────┐  │
                                 │  │  Support & Contribute│  │
      Rating < 4                 │  └────────────────────┘  │
           ↓                     └─────────────────────────┘
 ┌─────────────────────────┐
 │  How can we make        │
 │  it better?              │
 │                          │
 │  ┌────────────────────┐  │
 │  │  Send us an email  │  │
 │  └────────────────────┘  │
 └─────────────────────────┘
```

## Examples

### Android — with Play Store deep link

```dart
await AppReviewDialog.show(
  context,
  supportEmail: 'hello@myapp.com',
  storePackageName: 'com.example.myapp',
  supportWebsitePage: 'https://myapp.com/support',
);
```

### iOS — with App Store deep link

```dart
await AppReviewDialog.show(
  context,
  supportEmail: 'hello@myapp.com',
  appStoreId: '123456789',
  supportWebsitePage: 'https://myapp.com/support',
);
```

### Desktop / web — no store, just feedback & support

```dart
await AppReviewDialog.show(
  context,
  supportEmail: 'hello@myapp.com',
  supportWebsitePage: 'https://myapp.com/support',
);
```

### Custom threshold

```dart
// 3 stars and above → positive
await AppReviewDialog.show(
  context,
  supportEmail: 'hello@myapp.com',
  storePackageName: 'com.example.myapp',
  minPositiveRating: 3,
);
```

### Overriding strings

```dart
await AppReviewDialog.show(
  context,
  supportEmail: 'hello@myapp.com',
  storePackageName: 'com.example.myapp',
  title: 'Enjoying MyApp?',
  positiveTitle: 'Awesome! 🎉',
  positiveSubtitle: 'Help us spread the word!',
  negativeTitle: 'Tell us what went wrong',
  continueButtonLabel: 'Next',
  rateButtonLabel: 'Write a review',
  supportButtonLabel: 'Help & FAQ',
  emailButtonLabel: 'Talk to us',
);
```

### Using the result for analytics

```dart
final result = await AppReviewDialog.show(
  context,
  supportEmail: 'hello@myapp.com',
  storePackageName: 'com.example.myapp',
);

if (result == null) return;

switch (result.action) {
  case AppReviewDialogAction.ratedPositive:
    analytics.log('review_positive', rating: result.rating);
  case AppReviewDialogAction.ratedNegative:
    analytics.log('review_negative', rating: result.rating);
  case AppReviewDialogAction.dismissed:
    analytics.log('review_dismissed');
}
```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `supportEmail` | `String` | **required** | Email for the feedback button |
| `storePackageName` | `String?` | `null` | Android package name → `market://` deep link |
| `appStoreId` | `String?` | `null` | iOS App Store ID → `itms-apps://` deep link |
| `supportWebsitePage` | `String?` | `null` | URL for the "Support & Contribute" button |
| `minPositiveRating` | `double` | `4` | Threshold between positive/negative flows |
| `locale` | `Locale?` | auto | Override the displayed language |
| `title` | `String?` | localised | "How much do you enjoy the app?" |
| `positiveTitle` | `String?` | localised | Title on positive outcome |
| `positiveSubtitle` | `String?` | localised | Subtitle on positive outcome |
| `negativeTitle` | `String?` | localised | Title on negative outcome |
| `negativeSubtitle` | `String?` | localised | Subtitle on negative outcome |
| `rateButtonLabel` | `String?` | localised | "Rate in store" button |
| `supportButtonLabel` | `String?` | localised | "Support & Contribute" button |
| `emailButtonLabel` | `String?` | localised | "Send us an email" button |
| `continueButtonLabel` | `String?` | localised | "Continue" button |

## Return value

`AppReviewDialogResult` — `null` if never shown.

| Field | Type | Description |
|---|---|---|
| `rating` | `double` | 1–5 (integer) |
| `action` | `AppReviewDialogAction` | `ratedPositive`, `ratedNegative`, `dismissed` |

## Theming

The dialog follows your app's `ThemeData.colorScheme` out of the box:

| Element | Color |
|---|---|
| Stars, icons, filled buttons | `colorScheme.primary` |
| Title | `colorScheme.onSurface` |
| Subtitles | `colorScheme.onSurfaceVariant` |
| Card background | `colorScheme.surface` |
| Card border | `colorScheme.outlineVariant` |

Dark mode is fully supported — no extra configuration.

## Supported locales

`ar` · `ca` · `da` · `de` · `el` · `en` · `es` · `fr` · `hr` · `it` · `ja` ·
`or` · `pl` · `pt` · `pt-BR` · `pt-PT` · `ru` · `ta` · `tr` · `uk` · `vec` ·
`zh`

## Publishing to pub.dev

Tag a release:

```bash
git tag v1.0.0
git push --tags
```

The GitHub Actions workflow in `.github/workflows/publish.yml` will analyze,
format-check, and publish to pub.dev automatically.

## License

MIT
