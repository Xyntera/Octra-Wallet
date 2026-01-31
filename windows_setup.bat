
@echo off
TITLE Octra Wallet - Windows Setup

echo [1/4] Enabling Desktop Support...
call flutter config --enable-windows-desktop

echo [2/4] Configuring Project (app.octrawallet)...
:: Using --org app.octrawallet sets the Bundle ID
call flutter create . --platforms=windows --org app.octrawallet

echo [3/4] getting packages & icons...
call flutter pub get
call flutter pub run flutter_launcher_icons

echo [4/4] Building Windows Executable...
call flutter build windows --release

echo.
echo ========================================================
echo BUILD COMPLETE
echo ========================================================
echo Your app is ready at:
echo build\windows\runner\Release\octra_wallet.exe
echo.
pause
