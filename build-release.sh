#!/bin/bash
# Production release build for HisabEasy SMS Sync app.
# Run this after placing the keystore at android/hisabeasy-release.jks
# and filling in android/key.properties.

set -e

flutter build apk --release \
  --dart-define=API_BASE_URL=https://hisabeasy.online \
  --dart-define=WEBHOOK_SECRET=bcc9130943c00c3f94d36c6f1f0c0a3db278b16f3564fcb2b7d2d4814d15d46d

echo "APK: build/app/outputs/flutter-apk/app-release.apk"
