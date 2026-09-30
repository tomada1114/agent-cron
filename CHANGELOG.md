# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Initial project scaffold from [macos-app-template](https://github.com/tomada1114/macos-app-template)

### Changed

- AgentCron now lives in the menu bar: a clock status item opens a placeholder popover,
  and its Open AgentCron… command (⌘,) opens a placeholder main window. The app no
  longer shows a Dock icon or opens a window at launch.
- The app's accent color is now deep teal (the design lock, ADR-0009), in light and dark.

### Removed

- The template's counter example screen

[Unreleased]: https://github.com/tomada1114/agent-cron/commits/main
