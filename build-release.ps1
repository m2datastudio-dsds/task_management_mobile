$version = "v0.1"

flutter clean
flutter pub get
flutter build apk --release

New-Item -ItemType Directory -Force "apk" | Out-Null

Copy-Item `
    "build\app\outputs\flutter-apk\app-release.apk" `
    "apk\apk-$version.apk"

Write-Host "APK created: apk\apk-$version.apk"