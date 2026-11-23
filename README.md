# FC 26 Launcher for macOS

[![RecompLauncher](https://img.shields.io/badge/RecompLauncher-supported-brightgreen?logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgd2lkdGg9IjI0IiBoZWlnaHQ9IjI0Ij48cGF0aCBmaWxsPSIjZmZmIiBkPSJNMTIgMkM2LjQ4IDIgMiA2LjQ4IDIgMTJzNC40OCAxMCAxMCAxMCAxMC00LjQ4IDEwLTEwUzE3LjUyIDIgMTIgMnptMCAxOGMtNC40MSAwLTgtMy41OS04LThzMy41OS04IDgtOCA4IDMuNTkgOCA4LTMuNTkgOC04IDh6bTAtMTRjLTMuMzEgMC02IDIuNjktNiA2czIuNjkgNiA2IDYgNi0yLjY5IDYtNi0yLjY5LTYtNnoiLz48L3N2Zz4=)](https://recomplauncher.com/game/ea-sports-fc-26)

A modern, native macOS launcher for **EA SPORTS FC 26** (Switch version recompiled to run natively on Apple Silicon).

Built on top of [nxnative](https://github.com/seedds/nxnative) by seedds.

## RecompLauncher Support

This launcher includes full [RecompLauncher](https://recomplauncher.com) integration:

- **Easy Setup**: Select your build folder and launch
- **Settings Panel**: All game settings exposed in the launcher UI
- **Preparation & Verification**: Validates build folder and prepares game data with progress reporting

The `recomplauncher.json` is included in the app bundle at `Contents/Resources/recomplauncher.json` and at the app root for distribution.

## Features

- 🎮 **Game Browser** - Select your FC 26 build folder (`01004FF021942000_build`)
- 🔨 **One-Click Build** - Compiles a standalone `.app` using `pack_app.py` from nxnative
- ⚙️ **Full Settings Panel** - All game options from `launcher.json` (frame rate, display mode, language, controls, performance)
- 🚀 **120 FPS Mod** - Toggle 120 FPS support with automatic patch application
- ☁️ **Cloud Saves** - Configure iCloud Drive folder for cross-device save sync
- 🎨 **Modern macOS UI** - Native SwiftUI with sidebar navigation, supports light/dark mode
- 📦 **Self-Contained App** - No dependencies, runs on macOS 14+

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

- macOS 14.0 (Sonoma) or later
- Apple Silicon Mac (M1/M2/M3)
- FC 26 Switch build folder (`01004FF021942000_build`)
- [nxnative](https://github.com/seedds/nxnative) repository at `/Users/faycalelhandi/nxnative`

## Installation

### Download Release
1. Go to [Releases](https://github.com/yourusername/FC26Launcher/releases)
2. Download `FC 26 Launcher.app.zip`
3. Unzip and move to Applications

### Build from Source
```bash
git clone https://github.com/yourusername/FC26Launcher.git
cd FC26Launcher
./build.sh
open .build/"FC 26 Launcher.app"
```

## Usage

1. **Launch the app** - Opens to the Game tab
2. **Select Build Folder** - Click "Select Build Folder" and choose your `01004FF021942000_build` folder
3. **Configure Settings** (optional) - Go to Settings tab to adjust:
   - Frame rate (30/60 FPS)
   - Display mode (Window/Fullscreen)
   - Language
   - Controls (rumble, layout)
   - Performance (upscaling, frame buffering, Metal HUD)
4. **Enable 120 FPS Mod** (optional) - Go to Mods tab and toggle "120 FPS Mod"
5. **Build** - Click "Build" in toolbar to create the standalone game app
6. **Launch** - Click "Launch" to start playing!

## 120 FPS Mod Details

The 120 FPS mod applies a patch from nxnative that enables:
- `fps_max 120` setting
- 120 Hz present pacing
- Frame regulator wait rate at 127.66 / reported 120
- Simulation at 120 FPS

**Requirements:**
- ProMotion display (120 Hz) - MacBook Pro 14"/16" (2021+), Studio Display, Pro Display XDR
- Game rebuild after enabling
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