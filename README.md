# FC 26 Launcher for macOS

[![RecompLauncher](https://img.shields.io/badge/RecompLauncher-supported-brightgreen?logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgd2lkdGg9IjI0IiBoZWlnaHQ9IjI0Ij48cGF0aCBmaWxsPSIjZmZmIiBkPSJNMTIgMkM2LjQ4IDIgMiA2LjQ4IDIgMTJzNC40OCAxMCAxMCAxMCAxMC00LjQ4IDEwLTEwUzE3LjUyIDIgMTIgMnptMCAxOGMtNC40MSAwLTgtMy41OS04LThzMy41OS04IDgtOCA4IDMuNTkgOCA4LTMuNTkgOC04IDh6bTAtMTRjLTMuMzEgMC02IDIuNjktNiA2czIuNjkgNiA2IDYgNi0yLjY5IDYtNi0yLjY5LTYtNnoiLz48L3N2Zz4=)](https://recomplauncher.com/game/ea-sports-fc-26)

A modern, native macOS launcher for **EA SPORTS FC 26** (Switch version recompiled to run natively on Apple Silicon).

Built on top of [nxnative](https://github.com/seedds/nxnative) by seedds.

## RecompLauncher Support

This launcher includes full [RecompLauncher](https://recomplauncher.com) integration:

- **Easy Setup**: Select your build folder and launch
- **Settings Panel**: All game settings exposed in the launcher UI
- **Preparation & Verification**: Validates build folder and prepares game data with progress reporting

The app bundle includes `recomplauncher.json` at `Contents/Resources/recomplauncher.json`.

## Features

- 🎮 **Game Browser** - Select your FC 26 build folder (`01004FF021942000_build`)
- 🔨 **One-Click Build** - Compiles a standalone `.app` using `pack_app.py` from nxnative
- ⚙️ **Full Settings Panel** - All game options from `launcher.json` (frame rate, display mode, language, controls, performance)
- 🚀 **120 FPS Mode** - Select 120 FPS with the patched FC 26 profile
- ☁️ **Cloud Saves** - Configure iCloud Drive folder for cross-device save sync
- 🎨 **Modern macOS UI** - Native SwiftUI with sidebar navigation, supports light/dark mode

## Screenshots

### Main Game Tab
![Main Game Tab](Screenshots/main-game-tab.png)

### Settings Panel
![Settings Panel](Screenshots/settings-panel.png)

### 120 FPS Mod
![120 FPS Mod](Screenshots/120fps-mod.png)

### Build Process
![Build Process](Screenshots/build-process.png)

### 120 FPS Gameplay
![120 FPS Gameplay](Screenshots/120fps-gameplay.png)

## Requirements

- Apple Silicon Mac with macOS 14 or later to open the launcher. Preparing game files requires the macOS version and build tools listed in the [nxnative setup guide for `65501fbb`](https://github.com/seedds/nxnative/blob/65501fbb/README.md#build-from-the-command-line).
- Your own Nintendo Switch copy of EA SPORTS FC 26, its **1.86.1233** update (`v1179648`), and `prod.keys` from your own Switch. The launcher download contains the launcher only.

## Installation

### Download Release

1. Download `FC.26.Launcher.v1.3.1.zip` under **Assets** on the [v1.3.1 release page](https://github.com/imnotsharingmyname/FC26Launcher/releases/tag/v1.3.1).
2. Unzip it and drag `FC 26 Launcher.app` to Applications.
3. Follow [Prepare your game](#prepare-your-game) before opening the launcher.

If macOS rejects the v1.3.1 bundle because of its signature, use [Build from Source](#build-from-source) to create a locally signed copy.

### Build from Source

```bash
git clone https://github.com/imnotsharingmyname/FC26Launcher.git
cd FC26Launcher
./build.sh
open ".build/FC 26 Launcher.app"
```

## Prepare your game

1. On your own Switch, use a dumping tool such as [nxdumptool](https://github.com/DarkMatterCore/nxdumptool/tree/rewrite) to export the base game (`.nsp` or cartridge `.xci`) and the installed `v1179648` update (`.nsp`). Copy both to a folder on your Mac, such as `~/Games/FC26`. Keep other updates out of this folder so nxnative selects the supported version. Have your console's `prod.keys` available locally, for example at `~/keys/prod.keys`.
2. Install the build tools and Python dependencies from the [pinned nxnative setup guide](https://github.com/seedds/nxnative/blob/65501fbb/README.md#build-from-the-command-line), using the following clone and patch commands. The [FC 26 source patch](https://github.com/imnotsharingmyname/nxnative-fc26-120fps#apply-it) adds the profile for this update and includes startup and controller fixes. Use `~/nxnative` as the checkout location for the **Build** button in launchers compiled from the current source. For an existing checkout of `65501fbb`, use that checkout and apply the patch once.

   ```bash
   git clone https://github.com/seedds/nxnative.git "$HOME/nxnative"
   git clone https://github.com/imnotsharingmyname/nxnative-fc26-120fps.git "$HOME/nxnative-fc26-120fps"
   cd "$HOME/nxnative"
   git checkout --detach 65501fbb
   git apply "$HOME/nxnative-fc26-120fps/patches/fc26-120fps-nxnative-65501fbb.patch"
   ```

3. From the patched nxnative checkout, run the command below. Adjust the dump and key paths if you used different locations. It creates `01004FF021942000_build` inside your dump folder and puts the packaged game where the launcher looks for it.

   ```bash
   apps="$HOME/Library/Application Support/FC26Launcher/Apps"
   mkdir -p "$apps"
   python3 scripts/build_ipa_from_nsp.py "$HOME/Games/FC26" \
     --keys "$HOME/keys/prod.keys" --platform mac-app --keep-extracted \
     --out "$apps/EA-Sports-FC-26.app"
   ```

4. Keep the generated build folder. It should contain `patched_v1179648/`, `extract/v1179648/RomFS.img`, `extract/v1179648/icon.jpg`, `shader/pkg/`, `app/launcher.json`, `font/nintendo_ext.ttf`, and `tools/dmhost`. If the update lacks `icon.jpg` but nxnative extracted one to `extract/v0/icon.jpg`, copy that file into `extract/v1179648/` so the launcher can validate the folder.

## Usage

1. Open FC 26 Launcher and click **Select Build Folder**. Choose the generated `01004FF021942000_build` directory.
2. Use **Settings** to adjust frame rate, display mode, language, controls, or performance.
3. Click **Launch**. The Terminal build above already packaged the game, so go straight to **Launch**. In the v1.3.1 download, use that Terminal command whenever you need to rebuild the game because the app's **Build** button still uses a developer-specific path.

## 120 FPS Mod Details

Choose 120 FPS in **Settings** after building with the FC 26 patch. The patched profile enables the following.
- `fps_max 120` setting
- 120 Hz present pacing
- Frame regulator wait rate at 127.66 / reported 120
- Simulation at 120 FPS

**Requirements:**
- A display running at 120 Hz
- A game build produced with the FC 26 patch
- "Standard" upscaling recommended (saves ~1.8ms GPU budget)

**Performance (M1 Pro, 120 Hz):**
- Match: p50 8.3ms, p95 9.4ms, ~2/300 frames dropped
- El Libertador: 105-110 FPS (p50 9.0ms, p95 12.2ms)
- GPU: p50 4.8-5.2ms
- CPU Power: 2.3-2.5W

## Benchmarks

| Configuration | Resolution | Avg FPS | 1% Low | GPU Time | Notes |
|---------------|------------|---------|--------|----------|-------|
| 30 FPS | 1920×1080 | 30 | 30 | ~6ms | Baseline |
| 60 FPS | 1920×1080 | 60 | 58 | ~8ms | Regulator margin fix |
| 120 FPS | 1920×1080 | 118 | 105 | ~5ms | ProMotion only |
| 120 FPS + MetalFX | 3600×2025 | 108 | 95 | ~7ms | +2ms upscaling cost |

*Tested on MacBook Pro M1 Pro 16GB, macOS 14, battery power*

## Project Structure

```
FC26Launcher/
├── Package.swift              # Swift Package Manager config
├── build.sh                   # Build script
├── .gitignore
├── README.md
└── Sources/FC26Launcher/
    ├── main.swift             # App entry point
    ├── Models/
    │   ├── GameManager.swift  # Build folder detection, validation, launch
    │   ├── SettingsManager.swift # launcher.json parsing, preferences
    │   └── BuildManager.swift   # pack_app.py execution, 120fps patch
    ├── Views/
    │   └── ContentView.swift  # Main UI with tabs (Game, Settings, Mods, About)
    └── Resources/
        └── Info.plist         # App bundle info
```

## How It Works

1. **Build Folder Detection** - Validates required paths:
   - `patched_v1179648/` - Rewritten NSO modules
   - `extract/v1179648/RomFS.img` - Game filesystem
   - `shader/pkg/` - Metal shader libraries
   - `app/launcher.json` - Settings schema
   - `font/nintendo_ext.ttf` - System font
   - `tools/dmhost` - Mac host binary

2. **Build Process** - Runs `nxnative/dm/mac/pack_app.py` which:
   - Compiles Swift/C launcher (`launcher.c` + `Launcher.swift`)
   - Copies game assets (APFS clones when possible)
   - Creates signed `.app` bundle

3. **120 FPS Patch** - Applies `fc26-120fps-nxnative-65501fbb.patch` to nxnative:
   - Modifies `hle_fpslock.c` for 120 FPS regulator
   - Updates frame pacing for 120 Hz displays
   - Extracts new files from `fc26-new-files.tar`

4. **Settings** - Reads `launcher.json` schema, saves preferences as `launcher.<ENV_VAR>` in UserDefaults

## Credits

- **nxnative** by [seedds](https://github.com/seedds/nxnative) - Core recompilation technology
- **d2r-mobile** by jhaizhou-ops - Native execution approach
- **Ryujinx** - Shader translation
- **Atmosphère** - Horizon kernel reference
- **LibHac** - NSP reading
- **SPIRV-Cross** - SPIR-V to Metal
- **glslang** - GLSL to SPIR-V

## License

MIT License - See [LICENSE](LICENSE) for details.

This project is not affiliated with Nintendo, Electronic Arts, or any game publisher.
