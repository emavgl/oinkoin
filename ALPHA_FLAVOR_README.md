# Alpha Flavor Configuration

## Overview
The "alpha" flavor has been successfully added to the Oinkoin app. It is configured as a premium variant (like "pro") but with a distinct package name and custom orange-tinted icons.

## Configuration Details

### Package Name
- **Package ID**: `com.github.emavgl.piggybank.alpha.pro`
- **Ends with "pro"**: ✓ Yes (recognized as premium by the app)
- **App Name**: Oinkoin Alpha

### Icons
- **Location**: `android/app/src/alpha/res/mipmap-*/`
- **Color**: Orange tint (#FF9800) applied to differentiate from other flavors
- **Densities**: hdpi, mdpi, xhdpi, xxhdpi, xxxhdpi
- **Adaptive Icon**: Configured with custom background, foreground, and monochrome images

## Building the Alpha Flavor

### Command Line Builds

**Debug APK:**
```bash
flutter build apk --flavor alpha --debug
```

**Release APK (split per ABI):**
```bash
flutter build apk --split-per-abi --flavor alpha --release
```

**Release App Bundle (for Play Store):**
```bash
flutter build appbundle --obfuscate --split-debug-info=./build-debug-file --flavor alpha
```

### Using the Build Script
The `build.sh` script has been updated to include the alpha flavor:
```bash
./build.sh
```

The alpha bundle will be copied to `./tmp_build/alpha/` and then to `~/Desktop/tmp_build/alpha/`

## Flavor Comparison

| Flavor | Package Name | Premium | App Name | Icon Color |
|--------|-------------|---------|----------|-----------|
| dev | com.github.emavgl.piggybank.dev.pro | ✓ | Oinkoin Debug | Default |
| free | com.github.emavgl.piggybank | ✗ | Oinkoin | Default |
| pro | com.github.emavgl.piggybankpro | ✓ | Oinkoin Pro | Default |
| **alpha** | com.github.emavgl.piggybank.alpha.pro | ✓ | Oinkoin Alpha | **Orange** |
| fdroid | com.github.emavgl.piggybankpro | ✓ | Oinkoin | Default |

## Premium Detection
The app checks if the package name ends with "pro" to determine premium status:
```dart
ServiceConfig.isPremium = packageInfo.packageName.endsWith("pro");
```

Since the alpha package name (`com.github.emavgl.piggybank.alpha.pro`) ends with "pro", it will have all premium features enabled.

## Files Modified/Created

### Modified:
1. `android/app/build.gradle` - Added alpha flavor configuration
2. `build.sh` - Added alpha flavor to build script

### Created:
1. `android/app/src/alpha/res/mipmap-*/` - Icon resources with orange tint
2. `android/app/src/alpha/res/mipmap-anydpi-v26/ic_launcher.xml` - Adaptive icon configuration

## Testing
You can test the alpha flavor by:
1. Building and installing the APK: `flutter run --flavor alpha`
2. Verifying the app name shows as "Oinkoin Alpha"
3. Verifying the icon has an orange tint
4. Verifying premium features are enabled
5. Checking the package name in Settings > Apps

## Notes
- The alpha flavor shares the same codebase as all other flavors
- Only the package name, app name, and icons are different
- All premium features are available in the alpha flavor
- The orange tint helps visually distinguish the alpha build from production builds
