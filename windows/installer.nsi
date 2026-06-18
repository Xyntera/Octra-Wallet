Unicode True

; Pass version + absolute paths at build time, e.g.
;   makensis /DVERSION=1.2.0 /DSRCDIR=<abs> /DOUTFILE=<abs> windows\installer.nsi
!ifndef VERSION
  !define VERSION "1.2.0"
!endif
!ifndef SRCDIR
  !define SRCDIR "build\windows\x64\runner\Release"
!endif
!ifndef OUTFILE
  !define OUTFILE "Octra-Wallet-Setup.exe"
!endif

!define APP_NAME   "Octra Wallet"
!define APP_EXE    "ouqro_wallet.exe"
!define PUBLISHER  "Octra Wallet"
!define REG_ROOT   "Software\OctraWallet"
!define REG_UNINST "Software\Microsoft\Windows\CurrentVersion\Uninstall\OctraWallet"

!include MUI2.nsh
!include x64.nsh

Name "${APP_NAME} ${VERSION}"
BrandingText "${APP_NAME} ${VERSION}"
OutFile "${OUTFILE}"
RequestExecutionLevel admin
ShowInstDetails show
ShowUninstDetails show

InstallDir "$PROGRAMFILES64\${APP_NAME}"
InstallDirRegKey HKLM "${REG_ROOT}" "InstallDir"

!define MUI_WELCOMEPAGE_TITLE "Welcome to ${APP_NAME} ${VERSION} Setup"
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN "$INSTDIR\${APP_EXE}"
!define MUI_FINISHPAGE_RUN_TEXT "Launch ${APP_NAME}"
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

Section "!${APP_NAME}" SecMain
  SectionIn RO
  SetOutPath "$INSTDIR"
  ; SRCDIR is an absolute path passed from CI; '*' includes extension-less
  ; files (NOTICES) and the data/ subtree.
  File /r "${SRCDIR}\*"

  CreateDirectory "$SMPROGRAMS\${APP_NAME}"
  CreateShortcut "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk" \
    "$INSTDIR\${APP_EXE}" "" "$INSTDIR\${APP_EXE}" 0
  CreateShortcut "$DESKTOP\${APP_NAME}.lnk" \
    "$INSTDIR\${APP_EXE}" "" "$INSTDIR\${APP_EXE}" 0

  WriteUninstaller "$INSTDIR\Uninstall.exe"

  WriteRegStr   HKLM "${REG_ROOT}"   "InstallDir"      "$INSTDIR"
  WriteRegStr   HKLM "${REG_UNINST}" "DisplayName"     "${APP_NAME}"
  WriteRegStr   HKLM "${REG_UNINST}" "DisplayVersion"  "${VERSION}"
  WriteRegStr   HKLM "${REG_UNINST}" "Publisher"       "${PUBLISHER}"
  WriteRegStr   HKLM "${REG_UNINST}" "InstallLocation" "$INSTDIR"
  WriteRegStr   HKLM "${REG_UNINST}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr   HKLM "${REG_UNINST}" "DisplayIcon"     "$INSTDIR\${APP_EXE},0"
  WriteRegDWORD HKLM "${REG_UNINST}" "NoModify"        1
  WriteRegDWORD HKLM "${REG_UNINST}" "NoRepair"        1
SectionEnd

Section "Uninstall"
  RMDir /r "$INSTDIR"
  RMDir /r "$SMPROGRAMS\${APP_NAME}"
  Delete "$DESKTOP\${APP_NAME}.lnk"
  DeleteRegKey HKLM "${REG_ROOT}"
  DeleteRegKey HKLM "${REG_UNINST}"
SectionEnd
