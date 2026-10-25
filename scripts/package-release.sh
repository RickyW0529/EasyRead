#!/bin/bash
set -euo pipefail

# Package an already built app. Signing/notarization status belongs in the release notes.
version="${1:?Usage: package-release.sh <x.y.z> <EasyRead.app> [output-directory]}"
app_path="${2:?An existing signed EasyRead.app is required}"
output_dir="${3:-dist/v$version}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Expected an x.y.z version.' >&2; exit 1; }
[[ -d "$app_path" && "$(basename "$app_path")" == EasyRead.app ]] || { echo 'Expected EasyRead.app.' >&2; exit 1; }
app_path="$(cd "$(dirname "$app_path")" && pwd)/EasyRead.app"
actual_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_path/Contents/Info.plist")
bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_path/Contents/Info.plist")
[[ "$actual_version" == "$version" && "$bundle_id" == com.easyread.EasyRead ]] || {
    echo 'App version or bundle identifier does not match this release.' >&2; exit 1;
}
codesign --verify --deep --strict "$app_path"
architectures=$(lipo -archs "$app_path/Contents/MacOS/EasyRead")
case "$architectures" in
    arm64) architecture=arm64 ;;
    x86_64) architecture=x86_64 ;;
    'x86_64 arm64' | 'arm64 x86_64') architecture=universal ;;
    *) echo "Unsupported architecture: $architectures" >&2; exit 1 ;;
esac
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
name="EasyRead-v$version-macos-$architecture"
for file in "$name.zip" "$name.dmg" SHA256SUMS.txt; do
    [[ ! -e "$output_dir/$file" ]] || { echo "Refusing to overwrite $file." >&2; exit 1; }
done
stage=$(mktemp -d "$output_dir/.package.XXXXXX")
trap 'rm -rf "$stage"' EXIT
mkdir "$stage/image"
ditto "$app_path" "$stage/image/EasyRead.app"
ln -s /Applications "$stage/image/Applications"
ditto -c -k --sequesterRsrc --keepParent "$stage/image/EasyRead.app" "$stage/$name.zip"
hdiutil create -quiet -volname "EasyRead $version" -srcfolder "$stage/image" -format UDZO "$stage/$name.dmg"
hdiutil verify -quiet "$stage/$name.dmg"
unzip -tq "$stage/$name.zip"
(
    cd "$stage"
    shasum -a 256 "$name.zip" "$name.dmg" > SHA256SUMS.txt
)
mv "$stage/$name.zip" "$stage/$name.dmg" "$stage/SHA256SUMS.txt" "$output_dir/"
echo "Packaged v$version ($architecture): $output_dir"
