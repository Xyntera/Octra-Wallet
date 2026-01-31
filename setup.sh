#!/bin/bash
set -e

echo "🔵 [1/5] Updating System..."
sudo apt-get update

echo "🔵 [2/5] Installing Prerequisites..."
# Essential build tools and libraries for Flutter Linux apps
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libsecret-1-dev libjsoncpp-dev

echo "🔵 [3/5] Configuring Flutter..."
flutter config --enable-linux-desktop

echo "🔵 [4/5] Generating Linux Configuration..."
# This generates the linux/ folder if missing, with correct Organization ID
flutter create . --platforms=linux --org app.octrawallet

echo "🔵 [6/6] Generating Icons & Building..."
flutter pub get
flutter pub run flutter_launcher_icons
flutter build linux --release

echo "✅ Build Complete!"
echo "Run your wallet using: ./build/linux/x64/release/bundle/octra_wallet"

