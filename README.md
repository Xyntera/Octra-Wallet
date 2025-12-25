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

**Octra Wallet** is a secure, fast, and private mobile wallet for the **Octra Network**. Built with Flutter, it offers a seamless experience for managing your assets with advanced privacy features and robust security.

## 🚀 Features

### 🔐 Security First
* **Non-Custodial**: You own your keys. Your mnemonic and private key never leave your device.
* **Biometric & PIN Protection**: Secure your wallet with optional Fingerprint/Face ID and a custom PIN.
* **Encrypted Storage**: Sensitive data is stored securely using hardware-backed encryption.

### 💸 Powerful Transactions
* **Send & Receive**: Fast and low-fee transactions on the Octra Network.
* **Transaction History**: Detailed view of your past transactions with rich metadata.
* **Staging & Nonce Management**: Intelligent handling of pending transactions.

### 🕵️ Privacy (Octra Exclusive)
* **Encrypted Balance**: Hide your holdings from the public ledger.
* **Private Transfers**: Send funds anonymously using encrypted envelopes.
* **Claim Transfers**: Securely claim private transfers with ephemeral keys.

### 🎨 Customization & UX
* **Multiple Wallets**: Create and manage multiple wallets in one app.
* **Customization**: Rename wallets and assign custom colors for easy identification.
* **Smooth Animations**: A polished, premium native feel with 60fps animations.
* **Dark Mode**: Sleek, eye-friendly interface.

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
