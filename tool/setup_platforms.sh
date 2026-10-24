#!/usr/bin/env bash
# One-time setup: creates the iOS and Android projects, then adds the
# permissions this app needs. Safe to run again.
#
#   cd /path/to/this/folder
#   bash tool/setup_platforms.sh com.yourname
#
# The argument is your bundle-ID prefix (must be unique to your Apple account).
set -euo pipefail
cd "$(dirname "$0")/.."

ORG="${1:-com.jennelledabu}"

echo "==> Creating platform folders (existing files are left alone)"
flutter create . --project-name mesh_app --org "$ORG" --platforms=web,android,ios
flutter pub get

# ---------------------------------------------------------------- iOS
PLIST="ios/Runner/Info.plist"
plist_set() {
  /usr/libexec/PlistBuddy -c "Set :$1 \"$2\"" "$PLIST" 2>/dev/null ||
    /usr/libexec/PlistBuddy -c "Add :$1 string \"$2\"" "$PLIST"
}
echo "==> iOS permission text"
plist_set NSCameraUsageDescription "The camera scans contact and package QR codes."
plist_set NSLocationWhenInUseUsageDescription "Your location is attached to help requests so helpers can find you."
plist_set NSFaceIDUsageDescription "Face ID locks the app so only you can open it."

# The QR scanner needs a recent iOS. Raise the minimum if it is lower.
PBX="ios/Runner.xcodeproj/project.pbxproj"
perl -pi -e 's/IPHONEOS_DEPLOYMENT_TARGET = (1[0-4]|[0-9])\.[0-9];/IPHONEOS_DEPLOYMENT_TARGET = 15.5;/g' "$PBX"
if [ -f ios/Podfile ]; then
  perl -pi -e "s/^#?\s*platform :ios, '[0-9.]+'/platform :ios, '15.5'/" ios/Podfile
fi

# ------------------------------------------------------------- Android
MANIFEST="android/app/src/main/AndroidManifest.xml"
echo "==> Android permissions"
for p in INTERNET ACCESS_FINE_LOCATION ACCESS_COARSE_LOCATION USE_BIOMETRIC CAMERA; do
  if ! grep -q "android.permission.$p\"" "$MANIFEST"; then
    perl -0pi -e "s|(<manifest[^>]*>)|\$1\n    <uses-permission android:name=\"android.permission.$p\"/>|" "$MANIFEST"
  fi
done

# "Call 911" needs to see the phone app on Android 11+.
if ! grep -q 'android.intent.action.DIAL' "$MANIFEST"; then
  if grep -q '<queries>' "$MANIFEST"; then
    perl -0pi -e 's|<queries>|<queries>\n        <intent>\n            <action android:name="android.intent.action.DIAL"/>\n            <data android:scheme="tel"/>\n        </intent>|' "$MANIFEST"
  else
    perl -0pi -e 's|</manifest>|    <queries>\n        <intent>\n            <action android:name="android.intent.action.DIAL"/>\n            <data android:scheme="tel"/>\n        </intent>\n    </queries>\n</manifest>|' "$MANIFEST"
  fi
fi

# The app lock (local_auth) needs a FragmentActivity.
MAIN=$(find android/app/src/main -name 'MainActivity.kt' | head -1)
if [ -n "$MAIN" ] && ! grep -q FlutterFragmentActivity "$MAIN"; then
  perl -pi -e 's/\bFlutterActivity\b/FlutterFragmentActivity/g' "$MAIN"
fi

echo
echo "Done. Next:"
echo "  flutter run -d chrome            # quickest look"
echo "  flutter devices                  # find your iPhone's ID"
echo "  flutter run -d <iPhone ID>       # on your phone"
echo "Before the first phone run, open ios/Runner.xcworkspace in Xcode and set"
echo "Runner > Signing & Capabilities > Team to your Personal Team."
