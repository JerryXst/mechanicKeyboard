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
