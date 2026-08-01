# tictactoe

Native macOS prototype that plays a low-latency mechanical click for global keyboard presses.

## Build

```sh
swift test
swift build -c release
```

Run the executable from Terminal. The first launch asks for Accessibility permission. The app lives in the menu bar and uses the system default audio output.

This prototype includes generated click assets so the project is self-contained. Replace the WAV files in `Sources/TicTacToe/Resources` with licensed recordings for production sound quality.
