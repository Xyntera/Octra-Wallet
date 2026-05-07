<div align="center">
  <img src="https://capsule-render.vercel.app/api?type=rect&color=001f5b&height=250&section=header&text=Octra%20Wallet&fontSize=70&fontColor=ffffff&animation=fadeIn&desc=Secure.%20Fast.%20Private.&descSize=20&descAlignY=70&descAlign=50" width="100%" />
  
  <br/>


  <img src="https://github.com/user-attachments/assets/e158dd0f-1bc4-41f1-a0ce-110f58dcbe56" width="120" alt="Octra Logo" />

  <br/><br/>

  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" />
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" />
  <img src="https://img.shields.io/badge/Security-Encrypted-green?style=for-the-badge" />

</div>

---

**Octra Wallet** is being refocused as a Flutter client for the **Octra Network**
with a native wallet-core bridge. The current native privacy backend uses the
vendored `native/vendor/webcli/pvac` C++ implementation through a C ABI.

## 🚀 Features

### 🔐 Security First
* **Non-Custodial**: You own your keys.
* **PIN Protection**: Local wallet access is protected with a custom PIN.
* **Encrypted Storage**: Sensitive data is stored securely using device storage.

### 💸 Wallet Operations
* **Public Balance**: View the current public balance for the active wallet.
* **Private Balance**: Decrypt encrypted balance locally through native PVAC.
* **Transaction History**: Detailed view of past transactions with metadata.
* **Public Send**: Sign and submit normal OCT transfers from Flutter.
* **Bulk Public Send**: Submit up to 5 public transfers with sequential nonces.
* **Privacy Operations**: Register PVAC key, encrypt, decrypt, stealth send, scan, and claim.
* **Tokens**: Discover token contracts, import a token by address, delete imported tokens, and send token transfers.
* **Refresh Support**: Pull to refresh for latest network state.

### 🎨 Customization & UX
* **Multiple Wallets**: Create and manage multiple wallets in one app.
* **Customization**: Rename wallets and assign custom colors for easy identification.
* **Smooth Animations**: A polished, premium native feel with 60fps animations.
* **Dark Mode**: Sleek, eye-friendly interface.

## Current Architecture

The chosen architecture is:

- Flutter UI in this repository
- native wallet core loaded through a Flutter FFI bridge
- vendored `native/vendor/webcli/pvac` C++ backend for PVAC privacy operations
- `webcli` kept as the upstream behavior reference only
- no wallet server process inside the APK

The app now has native PVAC-backed privacy paths wired into Flutter. Android and
iOS release packaging still require platform toolchains and crypto dependency
validation.

Technical docs live in [`docs/`](docs/).

GitHub Actions setup is documented in
[`docs/github-actions-build.md`](docs/github-actions-build.md).

## 📥 Download

Get the latest APK from the [Releases Page](https://github.com/Xyntera/Octra-Wallet/releases).

<p align="center">
  <img src="https://raw.githubusercontent.com/Xyntera/Octra-Wallet/main/assets/splash.png" width="300" alt="App Splash Screen" />
</p>

## 🛠️ Build from Source

### Prerequisites
* [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.5+)
* Dart SDK (3.0+)
* Android Studio / VS Code

### Steps

1.  **Clone the repository**
    ```bash
    git clone [https://github.com/Xyntera/Octra-Wallet.git](https://github.com/Xyntera/Octra-Wallet.git)
    cd Octra-Wallet
    ```

2.  **Install dependencies**
    ```bash
    flutter pub get
    ```

3.  **Run the app**
    ```bash
    flutter run
    ```

4.  **Build Release APK**
    ```bash
    flutter build apk --release
    ```
    The output will be in `build/app/outputs/flutter-apk/app-release.apk`.

## 🏗️ Tech Stack
* **Framework**: Flutter (Dart)
* **Cryptography**: `bip39`, `cryptography` (Ed25519, SHA256)
* **Storage**: `flutter_secure_storage`
* **State Management**: `Provider`
* **UI**: Cupertino (iOS-style) & Material

## 🤝 Contributing
Contributions are welcome! Please open an issue or submit a pull request.

## 📄 License
MIT License. See [LICENSE](LICENSE) for details.

---
<div align="center">
  <sub>Built by <a href="https://ouqro.tech">Ouqro.tech</a> | Code by Xyntera</sub>
</div>
