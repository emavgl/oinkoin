#!/usr/bin/env bash
#
# Builds the Linux release packages: the .deb and the .AppImage are made by
# flutter_distributor, the .rpm is built here from
# linux/packaging/rpm/oinkoin.spec.
#
# The RPM is not built by flutter_distributor because its generated spec copies
# the app bundle with paths relative to the build directory, which breaks with
# rpm >= 4.20 (the scriptlets run in a generated %{name}-%{version}-build
# directory instead of %{_topdir}/BUILD). The spec in this repository uses
# absolute paths, so it builds with both old and new rpmbuild.
#
# Requires flutter and flutter_distributor on PATH; everything is written below
# dist/ in the repository root.
set -euo pipefail

cd "$(dirname "$0")/.."

bundle_dir="build/linux/x64/release/bundle"
rpm_topdir="$PWD/dist/rpmbuild"

version=$(sed -n 's/^version: \([^+]*\)+.*/\1/p' pubspec.yaml)
build_number=$(sed -n 's/^version: [^+]*+\([0-9]*\).*/\1/p' pubspec.yaml)
if [[ -z "$version" || -z "$build_number" ]]; then
  echo "Cannot read the version from pubspec.yaml" >&2
  exit 1
fi

echo "Building .deb and .AppImage for $version+$build_number"
flutter_distributor release --name=linux-release

echo "Building .rpm for $version+$build_number"
rm -rf "$rpm_topdir"
mkdir -p "$rpm_topdir/BUILD/oinkoin"
cp -r "$bundle_dir"/* "$rpm_topdir/BUILD/oinkoin/"
install -m 0644 linux/packaging/rpm/oinkoin.desktop "$rpm_topdir/BUILD/oinkoin/"
install -m 0644 linux/assets/oinkoin.png "$rpm_topdir/BUILD/oinkoin/"

# The Flutter bundle carries the build directory in the libraries' rpath, as in
# the .deb and .AppImage packages. Silence the rpath checks of the brp helpers
# instead of failing the package (the old flutter_distributor rpm maker set the
# same value).
export QA_RPATHS=$((0x0001 | 0x0010))

rpmbuild --define "_topdir $rpm_topdir" \
  --define "app_version $version" \
  --define "app_release $build_number" \
  -bb linux/packaging/rpm/oinkoin.spec

echo "Packages:"
find dist \( -name '*-linux.deb' -o -name '*-linux.AppImage' -o -name '*.rpm' \) | sort
