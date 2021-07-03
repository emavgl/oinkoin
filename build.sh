flutter packages get

# Clean temporary folder
rm -rf ~/Desktop/tmp_build
mkdir ~/Desktop/tmp_build/

# build free version
sed -i "" 's/Oinkoin Debug/Oinkoin/' ./android/app/src/main/AndroidManifest.xml
sed -i "" 's/Oinkoin Pro/Oinkoin/' ./android/app/src/main/AndroidManifest.xml
sed -i "" 's/com.github.emavgl.piggybankprodebug/com.github.emavgl.piggybank/' android/app/build.gradle
sed -i "" 's/com.github.emavgl.piggybankpro/com.github.emavgl.piggybank/' android/app/build.gradle
sed -i "" 's/isPremium = true/isPremium = false/' ./lib/services/service-config.dart
flutter build apk --obfuscate --split-debug-info=./build-debug-files --split-per-abi
cp -r build/app/outputs/flutter-apk/ ~/Desktop/tmp_build/free-apk

# build premium version
sed -i "" 's/Oinkoin Debug/Oinkoin Pro/' ./android/app/src/main/AndroidManifest.xml
sed -i "" 's/Oinkoin/Oinkoin Pro/' ./android/app/src/main/AndroidManifest.xml
sed -i "" 's/com.github.emavgl.piggybankprodebug/com.github.emavgl.piggybankpro/' ./android/app/build.gradle
sed -i "" 's/com.github.emavgl.piggybank/com.github.emavgl.piggybankpro/' ./android/app/build.gradle
sed -i "" 's/isPremium = false/isPremium = true/'  ./lib/services/service-config.dart
flutter build apk --obfuscate --split-debug-info=./build-debug-files --split-per-abi
cp -r build/app/outputs/flutter-apk/ ~/Desktop/tmp_build/premium-apk

# build premium version
sed -i "" 's/Oinkoin Pro/Oinkoin Debug/' ./android/app/src/main/AndroidManifest.xml
sed -i "" 's/com.github.emavgl.piggybankpro/com.github.emavgl.piggybankprodebug/' ./android/app/build.gradle
sed -i "" 's/isPremium = false/isPremium = true/'  ./lib/services/service-config.dart
flutter build apk --obfuscate --split-debug-info=./build-debug-files --split-per-abi
cp -r build/app/outputs/flutter-apk/ ~/Desktop/tmp_build/debug-apk
