# 🎱 Snooker Manager

A snooker club management app built with **Flutter**. It helps a club owner keep track of games, visitor accounts (khata), century sessions and daily reports, all from an Android phone.

## 📥 Download

The ready-to-install **APK file is available in the [Releases](../../releases) section** of this repository.

1. Open the **Releases** section on the right side of this page.
2. Download the latest `.apk` file.
3. Open it on your Android phone and install it (allow "Install from unknown sources" if Android asks).

## ✨ Features

- **Khata (Ledger):** Keep a separate account for every visitor, with the games they played, the amount they owe, and the payments they have made.
- **Century Section:** 4, 5 or more players can play a century together. Each player's name is shown with their own score, and the score updates as points are added.
- **Time-based Century Charge:** Set the hourly rate in Settings. The start time is noted when a century begins, and the charge is calculated automatically from the elapsed time when it is closed.
- **Reports:** Review games, earnings and pending amounts.
- **Settings:** Configure rates and other options for your club.

## 🛠️ Tech Stack

- [Flutter](https://flutter.dev/) (Dart)
- Target platform: Android

## 🚀 Run from Source

Make sure Flutter is installed (`flutter doctor` should show no major problems), then:

```bash
git clone <your-repository-url>
cd snooker_manager
flutter pub get
flutter run
```

## 📦 Build the APK Yourself

```bash
flutter build apk --release
```

For smaller files (one APK per phone architecture):

```bash
flutter build apk --split-per-abi
```

The APK will be created in `build/app/outputs/flutter-apk/`.

## 📁 Project Structure

```
snooker_manager/
├── lib/          # Dart source code of the app
├── android/      # Android platform files (app icon, manifest, Gradle)
├── assets/       # Images and icons
└── pubspec.yaml  # Dependencies and app configuration
```

## 🤝 Contributing

Suggestions and improvements are welcome. Feel free to open an issue or submit a pull request.
