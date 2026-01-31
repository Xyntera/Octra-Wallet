# Octra Wallet (Desktop Edition)

A secure, private, and fast wallet for the Octra network.
Now ported for **Linux, Windows, and macOS** with an exclusive **Obsidian & Crimson** theme.

## Features
- **Cross-Platform**: Runs natively on Desktop and Mobile.
- **Secure**: Local key generation and AES-GCM encryption (compatible with CLI).
- **Private**: Encrypted balances and private transfers.
- **Visuals**: High-contrast Obsidian & Crimson design with large typography.

## 🚀 How to Build (Important)

Since this project was originally for Android, you must first enable desktop support.

### 1. Enable Desktop Platforms
Run this command in the project folder to generate the necessary `windows`, `linux`, and `macos` folders:
```bash
flutter create . --platforms=windows,linux,macos
```

### 2. Build for Your OS

#### Windows (.exe)
Generates an executable file.
```bash
flutter build windows
```
*Output: `build/windows/runner/Release/octra_wallet.exe`*

#### Linux (Binary / .deb)
Generates a portable binary. For `.deb` creation, you can use `flutter_to_debian`.
```bash
flutter build linux
```
*Output: `build/linux/x64/release/bundle/octra_wallet`*

#### macOS (.app)
Generates a macOS App Bundle.
```bash
flutter build macos
```
*Output: `build/macos/Build/Products/Release/octra_wallet.app`*

## Theme
- Primary: Crimson (`#DC143C`)
- Background: Obsidian (`#000000`)
- Font: Google Fonts Outfit
