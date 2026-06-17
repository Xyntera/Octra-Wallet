# Octra Wallet v1.2.0

## Highlights

### Native installers for all desktop platforms (new)
- **Windows** — NSIS `.exe` installer: installs to `Program Files`, creates Start Menu + Desktop shortcuts, includes an Add/Remove Programs uninstaller entry
- **macOS** — `.dmg` disk image with drag-to-Applications for standard macOS install experience (in addition to the existing `.zip`)
- **Linux** — `.deb` Debian/Ubuntu package with a proper application launcher, system-wide install, and Applications menu entry (in addition to the existing portable `.tar.gz`)

### Release APK now properly signed
- Android build is signed with a 4096-bit RSA release keystore (via CI secrets) instead of debug keys
- The signed APK is suitable for submission to app stores and sideload platforms

### Package ID updated to com.octrawalllet
- All platforms: application identifier changed from the placeholder `com.example.ouqro_wallet` to `com.octrawalllet` (reverse-domain of octrawalllet.com)
- Existing wallet data is unaffected — the data is stored in flutter_secure_storage keyed by content, not by package name

## Install

| Platform | Asset | Type |
|---|---|---|
| Android 6.0+ | `Octra-Wallet-v1.2.0-android.apk` | Signed APK — sideload (enable *Install unknown apps*) |
| Windows 10/11 x64 | `Octra-Wallet-v1.2.0-windows-x64-Setup.exe` | NSIS installer — recommended |
| Windows 10/11 x64 | `Octra-Wallet-v1.2.0-windows-x64.zip` | Portable zip — extract and run |
| macOS 11+ (Apple Silicon) | `Octra-Wallet-v1.2.0-macos-arm64.dmg` | DMG — drag app to Applications |
| macOS 11+ (Apple Silicon) | `Octra-Wallet-v1.2.0-macos-arm64.zip` | Zip — extract and run |
| Linux x64 (Debian/Ubuntu) | `Octra-Wallet-v1.2.0-linux-x64.deb` | Debian package — `sudo dpkg -i` |
| Linux x64 (any distro) | `Octra-Wallet-v1.2.0-linux-x64.tar.gz` | Portable bundle — extract and run |

### Linux system requirements
- Debian/Ubuntu 22.04+ or compatible; OpenSSL 3, GTK 3, libsecret (all pre-installed on modern Ubuntu)
- For `.deb`: `sudo dpkg -i Octra-Wallet-v1.2.0-linux-x64.deb` then launch **Octra Wallet** from the Applications menu

### Windows notes
- SmartScreen may warn on first launch — click *More info → Run anyway*
- The installer adds an uninstaller to *Settings → Apps*

### macOS notes
- Gatekeeper will warn on first launch — right-click → *Open*
- Targets Apple Silicon (arm64); Intel Macs require a local build

## Verify downloads

```
sha256sum -c SHA256SUMS.txt --ignore-missing
```
