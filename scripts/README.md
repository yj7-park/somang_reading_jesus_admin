# Release Automation Script for Somang Reading Jesus Admin

## Overview
This script automates the build, packaging, and release processes for the Windows application.

## Prerequisites
- Flutter SDK installed and in PATH.
- `gh` (GitHub CLI) installed and authenticated (`gh auth status`).
- PowerShell 5.1 or higher.

## Usage
Run the following command from the project root:
```powershell
.\scripts\release.ps1
```

## What the script does:
1.  **Version Check**: Reads the version from `pubspec.yaml`.
2.  **Build**: Runs `flutter build windows --release`.
3.  **MSIX**: Runs `dart run msix:create` to generate the installer.
4.  **Portable ZIP**: Zips the build output into a `_portable.zip` file.
5.  **Git Tag**: Asks to tag the current commit with the version.
6.  **GitHub Release**: Creates a new GitHub release and uploads both ZIP and MSIX assets.
7.  **Sync**: Optionally pushes tags to the secondary remote (`somang_reading_jesus`).
