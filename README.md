# BetterFlux

A small macOS menu bar app that warms your screen at night and dims it further than the hardware minimum allows.

- **Warmth** — Schedule (warms up in the evening, cools down in the morning, with a gradual transition), Always, or Off.
- **Extra dimming** — go below the lowest built-in brightness, down to 5%.
- **Hotkeys** — ⌃⌥⌘↓ dim, ⌃⌥⌘↑ brighten, ⌃⌥⌘0 back to full brightness.
- Works on every connected display and keeps each display's ColorSync calibration. Turning warmth off also resets the dimming.

Requires macOS 15 or later.

## Build

```sh
./build.sh            # builds build/BetterFlux.app
./build.sh --install  # also copies it to /Applications
```

## License

MIT
