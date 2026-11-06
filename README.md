# Number Pick

Number Pick is a Flutter arithmetic practice game built around a simple drag-and-drop loop: solve an equation, find its result on the number board, and drag that tile onto the equation. Correct answers produce a new problem immediately, making the app useful for short practice sessions or longer drills.

## Gameplay

- Drag a numbered tile onto the equation it solves. Every visible equation has a matching answer tile on the board.
- Correct drops flash green, increase the correct count, and replace the equation and its answer tile.
- Incorrect drops flash red, increase the incorrect count, and leave the equation available for another attempt.
- Tap an equation to reveal its answer for about two seconds without changing the score.
- Practice Addition, Subtraction, Multiplication, Division, or any enabled combination. Division problems have whole-number answers.
- Enable Complex mode for longer parenthesized expressions with whole-number results; Complex scores are tracked separately.

New players with no recorded attempts are initially directed to the Help tab. The interface adapts across phone, tablet, and desktop widths, and the number board supports scrolling when all tiles cannot fit at once.

## Practice settings

- Set the minimum and maximum operand values.
- Choose how many equations and number tiles are displayed. There must be at least three answer tiles per equation.
- Enable individual arithmetic operations; at least one always remains active.
- Switch between Standard and Complex equations.
- Choose the System, Dark, or Light appearance. The appearance choice applies for the current session.
- Reset all score counters after a confirmation prompt without changing game settings.

The visible equation count can be reduced when the available screen height cannot accommodate the requested amount.

## Progress and storage

- Correct, incorrect, and total attempts, plus rounded accuracy, are shown per active operation.
- Letter grades begin at 70% accuracy: C at 70%, B at 80%, and A at 90%; lower scores have no letter grade.
- Complex-mode attempts are tracked separately from standard operations.
- Scores and game settings are stored locally with SharedPreferences and restored on the next launch.
- Theme selection applies during the current app session and is not persisted.

## Help and support

The in-app Help tab covers gameplay, difficulty, scoring, and support. The Information tab contains:

- **Contact:** sends the entered name, email address, and question to the configured support endpoint, together with detected app version, package name, platform, screen orientation, and layout details.
- **Submissions:** retrieves and displays support submissions associated with this app's package name.

Gameplay does not require a network connection. Sending a contact request and loading submissions do.

## Project layout

- `lib/app`: application shell, themes, and splash transition
- `lib/features/game`: game models, persistence, generation, scoring, and UI
- `lib/contact`: contact form and submissions viewer
- `store_listing`: Google Play short and long descriptions
- `scripts` and `tool`: release and maintenance PowerShell scripts

## Tech stack

- Flutter and Dart with Material 3
- `shared_preferences` for local scores and settings
- `http` for contact and submission requests
- `package_info_plus` for application metadata

## Supported targets

The repository contains Flutter platform projects for Android, web, Windows, iOS, macOS, and Linux. The release task chain currently builds Android APK/AAB, web, Windows, and MSIX artifacts.

## Getting started

1. Install Flutter with the prerequisites for your target platform.
2. Run `flutter pub get`.
3. Run `flutter run` and select a connected device or desktop/web target.

Useful checks:

```powershell
flutter analyze
```

## Release builds

The workspace provides these VS Code build tasks:

- `Build Release APK`
- `Build Release App Bundle`
- `Build Release Web`
- `Build Release Windows`
- `Build Release MSIX`
- `Build All Release Targets`

The all-target task performs the version bump and runs the configured release builds in sequence. Platform SDKs, signing configuration, and packaging prerequisites must be installed before running the corresponding target.
