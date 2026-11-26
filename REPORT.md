# RecompLauncher integration

The format-1 manifest names separate inputs for the Switch base game, the exact FC 26 update, and the player's shared `prod.keys`. Easy Setup checks the package metadata, then uses the patched nxnative build script. Play uses the same launcher binary and starts the built game directly with the selected RecompLauncher settings. The standalone SwiftUI app still opens when started without flags.

The macOS arm64 ZIP puts the manifest next to the signed app. The app and ZIP contain launcher code and generated artwork. Switch game data and keys come from the player.

## Verification

The manifest passed RecompLauncher's JSON schema. The arm64 build and the unpacked ZIP passed strict macOS code-signature verification. The standalone app started without arguments. Test fixtures exercised windowless setup, build progress, retry, rejection of the wrong update, and direct Play with settings. A local pre-existing game build stalled in the macOS dynamic loader both through the integration and when started directly. A fresh build from a Switch dump and a full game session still need testing.

## Upstream work

| Standard | What remains | Size |
| --- | --- | --- |
| Packaged Switch formats | The pinned builder supports NSP and XCI here. NUP support needs a newer nxnative build and a port of the FC 26 profile so players can use NUP backups. | Large |
| Verified dump catalog | Setup verifies the Nintendo title ID, update version, and resulting main build ID. Publishing a verified-copy badge needs independently verified size and CRC32 entries for exact Switch dumps. | Small once data is available |
| Standalone settings in a file | RecompLauncher settings are a JSON file. The standalone launcher still uses macOS preferences and would need a migration to share a readable file. | Medium |
| SDL and full controller navigation | nxnative uses Apple GameController. SDL remapping and controller-only navigation and quitting would need upstream host and UI work. | Large |
| Linux and Windows builds | The host and generated shaders use Apple frameworks and Metal. Other platforms need a compatible runtime and graphics backend. | Large |
| Recomp Achievements | An integration with reliable game events could add achievements, Beaten and Mastered tracking, and leaderboards. | Large |

[RecompLauncher developer guide](https://github.com/elripalda/RecompLauncher/blob/main/docs/DEVELOPERS.md) · [Recomp Achievements](https://github.com/elripalda/RecompAchievements) · [Claim this project](https://recomplauncher.com/dev)
