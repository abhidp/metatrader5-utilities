# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-01-07

### Added

- Initial release of Auto Stop Loss EA
- Automatic stop loss placement for manual trades
- ATR-based dynamic stop loss calculation
- Fixed pip-based stop loss option
- Trailing stop functionality with ATR adaptation
- Minimum pip distance protection
- Development environment setup scripts
- Auto-compilation scripts for development

### Technical Details

- ATR-based trailing mechanism
- Safety features to prevent too-tight stops
- Separate multipliers for initial and trailing stops
- Automatic error handling and logging
- Real-time compilation feedback

## How to Update This File

When making changes, add a new version section at the top:

```
## [1.1.0] - 2025-01-XX
### Added
- New feature X
- New feature Y

### Changed
- Modified how Z works
- Updated parameter A

### Fixed
- Bug in feature B
- Issue with function C
```

Version numbering explained:

- First number (1.x.x): Major changes/rewrites
- Second number (x.1.x): New features
- Third number (x.x.1): Bug fixes and minor changes

Example future entry:

```
## [1.1.0] - 2025-01-20
### Added
- Support for multiple currency pairs
- Custom risk percentage setting

### Changed
- Improved ATR calculation method
- Enhanced trailing stop logic

### Fixed
- Issue with minimum pip distance
- Bug in trailing stop updates
```
