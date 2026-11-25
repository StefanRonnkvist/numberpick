# Number Pick

Number Pick is an arithmetic practice game built around a drag-and-drop loop: solve an equation, find its result among the number tiles, and drag that tile onto the equation. Correct answers replace the problem, so you can keep practicing without restarting a round. Practice addition, subtraction, multiplication, division, or multi-operation expressions.

Current app version: `0.1.49+50` (from `pubspec.yaml`).

## Highlights
- Practice one or more standard operations, or switch to Complex mode for parenthesized expressions.
- Adjust the operand range, number of equations, and answer tiles to suit your session.
- Get immediate feedback, reveal an equation's answer briefly, and track scores, accuracy, and grades.
- Keep scores and practice settings on your device; gameplay works offline.

## How to play

- Drag a number tile onto the equation it solves. Every displayed equation has a matching answer tile.
- A correct drop flashes green, counts as a correct attempt, and replaces the equation and its answer tile.
- An incorrect drop flashes red and counts as an incorrect attempt; the equation remains for another try.
- Tap an equation to reveal its answer for about two seconds. Revealing an answer does not change your score.
- Practice addition, subtraction, multiplication, division, or a mix of the four. Division problems use whole-number answers.
- Turn on Complex for parenthesized expressions that combine operations. These attempts are scored separately from standard operation practice.

The app has four main sections:

- **Game** — solve and match equations while viewing scores.
- **Setting** — choose operations, mode, operand range, equation/tile counts, theme, and score reset.
- **Help** — learn the controls, modes, scoring, and support options.
- **Information** — contact support or view submissions.

Players with no recorded attempts initially see Help. The layout adapts to phone, tablet, and desktop widths; the tile board scrolls when needed.

## Practice settings

- Set the minimum and maximum operand values (from 0 to 999).
- Choose the number of displayed equations and number tiles. The tile count is at least three per equation and can be set up to 48.
- Enable one or more standard operations; at least one operation must remain enabled. Enabling Complex automatically selects all four operations for its expressions.
- Switch between Standard and Complex practice. Standard equations use one operation; Complex equations combine operations in parenthesized expressions.
- Choose System, Dark, or Light appearance. This choice lasts for the current app session and is not persisted.
- Reset score counters after confirming. Resetting scores keeps your practice settings.

The equation count is limited by available screen height, so fewer equations may be shown than the selected count when space is tight.

## Scores and saved data

- Score cards show correct, incorrect, and total attempts, plus accuracy rounded to a whole percent for each operation shown.
- Grades use accuracy thresholds: C from 70%, B from 80%, and A from 90%. There is no letter grade below 70%.
- Complex-mode attempts have a separate score.
- Scores and practice settings are saved locally with SharedPreferences and restored on the next launch.
- Theme selection applies during the current app session and is not persisted.
- After at least 100 attempts, crossing 90% overall accuracy triggers a confetti celebration.

## Help, contact, and submissions

The in-app **Help** section explains controls, practice settings, scores, and support. **Information** contains two sections:

- **Contact** sends the name, return email, and question you enter to the configured support service. The request also includes detected app version and build, package name, platform, screen orientation, and layout size category.
- **Submissions** downloads the submissions CSV and displays only rows matching this app's package name.

Gameplay works offline. Contacting support and loading submissions require an internet connection. Contact details and diagnostic metadata are sent only when you submit the form.

## Project layout

- `lib/app`: application shell, themes, and splash transition
- `lib/features/game`: game models, persistence, generation, scoring, and UI
- `lib/contact`: contact form and submissions viewer
- `store_listing/google_play_short_description.txt` and `store_listing/google_play_long_description.txt`: Google Play listing copy
- `scripts` and `tool`: release and maintenance PowerShell scripts

## Tech stack

- Flutter and Dart with Material 3
- `shared_preferences` for local scores and settings
- `http` for contact and submission requests
- `package_info_plus` for application metadata


## Supported targets

The configured release tasks build Android APK/AAB, web, and Windows/MSIX artifacts. Other Flutter platform folders may be present, but are not part of the configured release task chain.

## Getting started

1. Install Flutter with the prerequisites for your target platform.
2. Run `flutter pub get`.
3. Run `flutter run` and select a connected device or desktop/web target.

Useful checks:

```powershell
flutter analyze
```

## Release builds

Available VS Code tasks include `Build Release APK`, `Build Release App Bundle`, `Build Release Web`, `Build Release Windows`, `Build Release MSIX`, and `Build All Release Targets`. The all-target task bumps the version and runs its configured release builds in sequence. Install the relevant platform SDKs and configure signing and packaging prerequisites before building.
