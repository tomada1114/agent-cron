# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- The Jobs editor header has a Run Now button that turns into Stop while the job runs;
  it is off for a job that has not been saved yet.
- The UI is available in Japanese: every screen, menu, alert, and notification follows
  the system language (English or Japanese), with no in-app language switch.
- Initial project scaffold from [macos-app-template](https://github.com/tomada1114/macos-app-template)
- The main window has a sidebar with Jobs, History, and General (⌘1–⌘3), and reopens on
  the section you last left it on. The main menu
  gains Settings… (⌘,, opens General), New Job (⌘N), a Job menu (Run Now ⌘R, Stop ⌘.,
  Enable / Disable ⌘E, Delete… ⌘⌫), and Toggle Sidebar (⌃⌘S).
- The Jobs screen: a list of jobs with their schedule and next run beside an editor
  for the name, folder, prompt, weekday chips and presets, times, model, effort,
  permission, timeout, and notifications. Edits apply only on Save (⌘S), with Revert,
  and leaving a job with unsaved edits asks first. Choosing Bypass Permissions asks
  first and then shows a red warning; Delete Job… and Job › Delete… (⌘⌫ from the list)
  ask before deleting. ⌘⌫ in a text field still deletes to the start of the line.
- The History screen: runs grouped by day, newest first, filtered by job (deleted jobs
  marked "(deleted)") and outcome, beside the selected run's detail — its trigger,
  times, duration, cost, exit code, folder, model, effort, permission, and session, the
  result rendered as Markdown with Raw and Copy, the prompt it used (collapsed), a
  skipped run's reason, a failed run's error output, and, while it runs, the elapsed
  time and Stop. Open Job shows the run's job in Jobs.
- The menu-bar popover now shows today's timeline — finished runs with their outcome,
  duration, and cost (click one to open it in History), running runs with elapsed time
  and Stop, and upcoming runs — with a banner for failed runs since you last looked and
  for a missing claude CLI, empty states for no jobs, nothing today, and all jobs paused,
  a Keep awake menu (Off, 1 hour, 4 hours, Until turned off) with the time left, and New
  Job, Open AgentCron… (⌘,), and Quit (⌘Q). The status item shows a filled clock while a
  job runs, a cup while kept awake, and a red dot for unseen failures.
- The General screen: a Launch at login switch (with Open Login Items while macOS waits
  for your approval), where `claude` resolves in your login shell and its version with
  Check Again, and notes that the Mac stays awake while jobs run and that runs are kept
  for 90 days.
- Jobs now run on their schedule. A saved job fires at its times on its weekdays and
  re-arms whenever you save, wake the Mac, or change the clock or time zone; a time
  missed while the Mac slept or the app was closed runs once on wake or launch if it is
  at most 60 minutes old, and the rest are recorded as skipped. The Mac is kept out of
  idle sleep while any job runs. Each finished run shows in History and the popover at
  once and notifies according to the job's setting; clicking the notification opens
  History on that run. Run Now (⌘R) and Stop (⌘.) in the Job menu, Stop in the popover
  and in History, and deleting a running job all stop or start runs, and the status
  item reflects running jobs and unseen failures without opening the popover. A
  `jobs.json` that cannot be read at launch shows an alert with the reason and Quit /
  Try Again, and the file is never overwritten.

### Changed

- AgentCron now lives in the menu bar: a clock status item opens the popover, and its
  Open AgentCron… command (⌘,) opens the main window. The app shows a Dock icon and its
  main menu only while the main window is open, and opens no window at launch. The
  first launch turns on launch at login.
- The app's accent color is now deep teal (the design lock, ADR-0009), in light and dark.

### Fixed

- A job whose prompt starts with `-`, such as a Markdown bullet, now reaches Claude Code
  as its prompt instead of failing with an unknown-option error.

### Removed

- The template's counter example screen
- The template's `FrontmostApp` ports-and-adapters example and the unused placeholder
  popover view; `SleepPreventing` / `PowerAssertionSleepPreventer` is now the worked
  example

[Unreleased]: https://github.com/tomada1114/agent-cron/commits/main
