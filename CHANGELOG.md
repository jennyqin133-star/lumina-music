# Changelog

All notable changes to Lumina Music are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- SwiftPM build system (replaces direct `swiftc` compile).
- Sparkle 2.x auto-update integration.
- App icon (placeholder) generated from §9.0 brand color.
- GitHub Actions CI + release pipelines.
- Distribution via signed/notarized DMG on GitHub Releases.

### Changed
- Project layout reorganized into SwiftPM standard:
  `Sources/LuminaMusic/`, `Resources/`, `scripts/`, `docs/`, `assets/`.

### Removed
- Hard-coded `sk-` API key from `.env` (replaced by `~/.config/lumina/secrets.env`
  read at runtime; users must paste their own JWT from platform.minimaxi.com).

## [0.2.0] - 2026-06-24

### Notes
- Agent upload + link import; restructure to 4 tabs


## [0.1.2] - 2026-06-24

### Notes
- Fix transport bar on Agent tab; default to M3


## [0.1.1] - 2026-06-24

### Notes
- First distribution build


## [0.1.0] - 2026-06-19

### Added
- Initial Swift native macOS prototype by Mavis.
- Four-tab layout: Agent / Editor / DJ / Artwork.
- §9.0 visual spec: design tokens, SF Pro + SF Mono fonts, dark mode.
- `AudioEngine` (AVAudioEngine) + `AudioAnalyser` (BPM/LUFS/spectral centroid).
- Mock data across all tabs (UI complete, no live API).
