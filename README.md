# Preferans for iOS

Native iOS port of the Preferans card game (Swift + SwiftUI), translated verbatim
from the Android app (Kotlin/Compose), which itself is a port of the 2011
Windows Phone app.

## Layout

- `PrefEngine/` — Swift Package with the game model and AI, pure Swift
  (no UIKit/SwiftUI). Persistence via Codable JSON files using the same file
  names as the Android app (`lastgame.json`, `lastcalc.json`, `settings.json`,
  `highscores.json`, `pulya_yyyyMMddHHmmss_N_L.json`).
- `Pref/` — the SwiftUI app (iOS 16+): sources, card sprites, tutorials
  (ru/en/es), UTF-16 glossary, String Catalog (en base + ru + es).
- `project.yml` — XcodeGen project definition; `Pref.xcodeproj` is generated.

## Building

```sh
# Engine tests (plays complete games through all game types)
cd PrefEngine && swift test

# App
xcodegen generate
xcodebuild -project Pref.xcodeproj -scheme Pref \
  -destination 'generic/platform=iOS Simulator' build
```

If `xcode-select` points at the CommandLineTools, prefix commands with
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

## Porting notes (do not "fix" these)

- The engine is a verbatim translation. Several AI quirks are intentional and
  marked `NOTE: preserved from the original C#` — the heuristics were tuned
  around them.
- `Card`/`Hand`/`Bid` and the AI rasklad lists are reference types on purpose;
  the engine relies on reference identity and shared mutable lists
  (see `IntList`, `OrderedIntDict`).
- Kotlin `LinkedHashMap` insertion order is reproduced by `OrderedIntDict`
  (`isVister`, `curentBids`, `inPlay`, `aIs`, `GameResult.taken`).
- Every Kotlin runtime exception (including `!!` NPE sites the original app
  relied on catching) is a thrown `PrefError`, never a crash: the AI throws in
  rare positions by design and the UI/tests catch and continue.
- The game loop runs on a serial `DispatchQueue` off the main thread;
  the view model publishes immutable render snapshots to `@MainActor` and
  drives card-flight animations with its own progress loop.
- UI geometry uses the original virtual canvases: 480x716 for the table,
  480x550 for the score sheets, scaled to the screen.
- `dictionary.txt` is UTF-16 with BOM.
- Card sprites in `Pref/Resources/cards/` are AI-upscaled (296x392) from the
  original 37x49 WP7 sprites. Pipeline: upscayl-bin (Real-ESRGAN ncnn), two 4x
  passes, then `sips -Z 392`. The bundled set uses the realesrgan-x4plus
  (photo) model — a soft, painterly look. Alternatives kept next to it, not
  bundled: `cards_sharp_296px/` (realesrgan-x4plus-anime model, crisp line
  work) and `cards_original_37px/` (untouched originals). To switch looks,
  copy a set over `cards/` and rebuild. The card back (`0.png`) is drawn
  procedurally (the AI destroyed its fine lattice pattern).
- On iOS the app language is selected via per-app language in system Settings
  (`CFBundleLocalizations` lists en/ru/es).
