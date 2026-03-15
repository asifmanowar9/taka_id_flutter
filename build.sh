#!/usr/bin/env bash
set -euo pipefail

# Vercel runs as root; Flutter warns unless this is set.
export FLUTTER_ALLOW_ROOT=1

# Keep pub cache inside the project so it is writable.
export PUB_CACHE="$PWD/.pub-cache"

# Fetch Flutter SDK locally (stable channel)
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

export PATH="$PWD/flutter/bin:$PATH"

flutter config --enable-web
flutter doctor -v
flutter pub get
flutter build web --release --verbose
