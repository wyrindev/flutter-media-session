# Windows Setup Guide

SMTC identifies apps by **Application User Model ID (AUMID)**:
- **Packaged apps (MSIX)**: AUMID is assigned automatically from the manifest.
- **Unpackaged / portable apps**: No OS-assigned AUMID. SMTC requires an explicit process AUMID mapped to a Start Menu shortcut to resolve the display name and icon.

---

## Configuration Approaches

### 1. MSIX Packaging (Recommended for Store & Modern Distribution)

When packaged as an MSIX (for instance using the [`msix`](https://pub.dev/packages/msix) tool), Windows manages the identity and AUMID automatically:

1. Add `msix` to `dev_dependencies` in `pubspec.yaml`:
   ```yaml
   dev_dependencies:
     msix: ^3.16.1
   ```
2. Configure application parameters:
   ```yaml
   msix_config:
     display_name: My Media App
     publisher_display_name: My Company
     identity_name: com.mycompany.mymediaapp
     msix_version: 1.0.0.0
     logo_path: windows/runner/resources/app_icon.ico
   ```
3. Build and package:
   ```bash
   flutter build windows
   dart run msix:create
   ```

> When running inside an MSIX container, `flutter_media_session` detects the package runtime (`GetCurrentPackageFullName`) and skips shortcut registration to avoid conflicts.

---

### 2. Unpackaged / Portable Distribution

For portable builds (`.zip`) or unpackaged apps without an installer, call `setWindowsAppUserModelId` during early initialization:

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_media_session/flutter_media_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows) {
    // Call early before initializing playback sessions
    await FlutterMediaSession().setWindowsAppUserModelId(
      'Com.Company.MyApp',
      displayName: 'My App Name', // Creates Start Menu shortcut required by SMTC
      iconPath: r'C:\path\to\icon.ico', // Optional icon path
    );
  }

  runApp(const MyApp());
}
```

#### Under the Hood
1. Calls `SetCurrentProcessExplicitAppUserModelID` to identify the process to the Windows shell.
2. Checks `FOLDERID_Programs` and creates a Start Menu shortcut (`.lnk`) via COM `IShellLinkW` and `IPersistFile`.
3. Sets `PKEY_AppUserModel_ID` on the shortcut's `IPropertyStore` matching the AUMID.
4. Calls `SHChangeNotify(SHCNE_CREATE, SHCNF_PATH, ...)` to signal the shell to pick up the new association.

---

### 3. Custom Installers (Inno Setup / WiX)

If your app uses a Windows installer, configure it to attach the AUMID property directly to the Start Menu shortcut. Pass only `id` in Dart and omit `displayName`:

#### Dart Initialization
```dart
if (Platform.isWindows) {
  await FlutterMediaSession().setWindowsAppUserModelId('Com.Company.MyApp');
}
```

#### Inno Setup Configuration (`.iss`)
Attach `AppUserModelID` in the `[Icons]` section:
```ini
[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; AppUserModelID: "Com.Company.MyApp"
```

#### WiX Configuration (`.wxs`)
Add `ShortcutProperty` inside the `Shortcut` element:
```xml
<Shortcut Id="ApplicationStartMenuShortcut" Name="My Media App" Target="[#MyAppExe]">
    <ShortcutProperty Key="System.AppUserModel.ID" Value="Com.Company.MyApp" />
</Shortcut>
```

---

## Verifying the Setup

1. Launch your application and start media playback.
2. Activate the session via `session.activate()`.
3. Adjust the system volume slider or press `Win + G` to view the Windows Media Controller widget.
4. Confirm that your application display name and icon appear above the playback controls instead of "Unknown Application".

