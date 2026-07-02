# Mechanic Keyboard

A small macOS menu bar app that plays mechanical keyboard-style click sounds while you type.

## Build

```sh
./build_app.sh
```

The app bundle is created at:

```text
MechanicKeyboard.app
```

## Run

```sh
open MechanicKeyboard.app
```

macOS will ask for Accessibility permission so the app can hear global key events. If the prompt does not appear, open the menu bar keyboard icon and choose `Grant Accessibility Permission...`.

## Controls

- Enable or disable typing sounds from the menu bar icon.
- Adjust the volume from the menu.
- Choose one or more custom audio files for typing sounds. When multiple files are selected, each key press uses one at random.
- Switch back to the built-in synthesized mechanical click.
- Use `Test Click` to preview the sound.

The app stores its enabled state and volume in `UserDefaults`.

## Mac App Store

This repository includes an Xcode project for App Store archiving:

```sh
open MechanicKeyboard.xcodeproj
```

The App Store target uses:

- Bundle ID: `com.jerryxst.mechanickeyboard`
- Category: Utilities
- App Sandbox entitlement
- User-selected read-only file access for custom sound files
- `sounds/default.wav` as the bundled default typing sound

Archive from the command line with your Apple Developer Team ID:

```sh
DEVELOPMENT_TEAM=ABCDE12345 ./scripts/archive_app_store.sh
```

To export an App Store Connect package after archiving:

```sh
DEVELOPMENT_TEAM=ABCDE12345 ./scripts/archive_app_store.sh --export
```

If you use a different Bundle ID in App Store Connect:

```sh
DEVELOPMENT_TEAM=ABCDE12345 BUNDLE_ID=com.example.mechanickeyboard ./scripts/archive_app_store.sh
```

In App Review notes, explain that the app listens only for key press events to play local sound effects, does not record typed content, does not store keystrokes, and does not upload user data.
