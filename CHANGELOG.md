# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Initial project scaffold from [macos-app-template](https://github.com/tomada1114/macos-app-template)
- The main window has a sidebar with Jobs, History, and General (⌘1–⌘3), each a
  placeholder for now, and reopens on the section you last left it on. The main menu
  gains Settings… (⌘,, opens General), New Job (⌘N), a Job menu (Run Now ⌘R, Stop ⌘.,
  Enable / Disable ⌘E, Delete… ⌘⌫), and Toggle Sidebar (⌃⌘S).
- The Jobs screen: a list of jobs with their schedule and next run beside an editor
  for the name, folder, prompt, weekday chips and presets, times, model, effort,
  permission, timeout, and notifications. Edits apply only on Save (⌘S), with Revert,
  and leaving a job with unsaved edits asks first. Choosing Bypass Permissions asks
  first and then shows a red warning; Delete Job… and Job › Delete… (⌘⌫ from the list)
  ask before deleting. ⌘⌫ in a text field still deletes to the start of the line. It
  shows jobs once the app is wired to its job store; until then the section keeps its
  placeholder.
- The menu-bar popover now shows today's timeline — finished runs with their outcome,
  duration, and cost (click one to open it in History), running runs with elapsed time
  and Stop, and upcoming runs — with a banner for failed runs since you last looked and
  for a missing claude CLI, empty states for no jobs, nothing today, and all jobs paused,
  a Keep awake menu (Off, 1 hour, 4 hours, Until turned off) with the time left, and New
  Job, Open AgentCron… (⌘,), and Quit (⌘Q). The status item shows a filled clock while a
  job runs, a cup while kept awake, and a red dot for unseen failures. Stopping a run
  and keeping the Mac awake take effect once the scheduler is wired in.
- The General screen: a Launch at login switch (with Open Login Items while macOS waits
  for your approval), where `claude` resolves in your login shell and its version with
  Check Again, and notes that the Mac stays awake while jobs run and that runs are kept
  for 90 days. It shows once the app is wired to its login item and agent check; until
  then the section keeps its placeholder.

### Changed

- AgentCron now lives in the menu bar: a clock status item opens a placeholder popover,
  and its Open AgentCron… command (⌘,) opens a placeholder main window. The app no
  longer shows a Dock icon or opens a window at launch.
- The app's accent color is now deep teal (the design lock, ADR-0009), in light and dark.

### Removed

- The template's counter example screen

[Unreleased]: https://github.com/tomada1114/agent-cron/commits/main
