# EMR

## Build

1. Install Flutter and Inno Setup on a Windows machine.
2. From `frontend`, run `flutter pub get`.
3. Build the Windows app with `flutter build windows --release`.
4. Compile `frontend/installers/desktop_ino_script.iss` in Inno Setup to create the installer.

## Run

Use `flutter run -d windows` during development.
