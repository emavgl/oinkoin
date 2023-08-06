flutter packages get

# Clean temporary folder
rm -rf ./tmp_build
mkdir ./tmp_build

# build dev apk
flutter build apk --split-per-abi --split-debug-info=./build-debug-files --flavor dev
cp -r build/app/outputs/flutter-apk/ ./tmp_build/dev

# build free version
flutter build appbundle --obfuscate --split-debug-info=./build-debug-file --flavor free
cp -r build/app/outputs/bundle/freeRelease/ ./tmp_build/free

# build pro version
flutter build appbundle --obfuscate --split-debug-info=./build-debug-file --flavor pro
cp -r build/app/outputs/bundle/proRelease/ ./tmp_build/pro

# copy to desktop
rm -rf ~/Desktop/tmp_build
cp -r ./tmp_build ~/Desktop/tmp_build
