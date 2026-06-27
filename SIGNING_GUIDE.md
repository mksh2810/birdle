# Android Release Signing Guide

This guide explains how to use **`keytool`** (the JDK key management tool) and configure Flutter/Gradle to sign your release APK or Android App Bundle (AAB).

---

## Step 1: Generate a Keystore File

You need a keystore file containing your private key to sign the application. Generate one using JDK's `keytool` in your terminal:

```bash
keytool -genkey -v -keystore my-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias my-key-alias
```

During this command, you will be prompted to:
1. Choose a **keystore password** (Write this down!).
2. Enter your name, organization details, and location.
3. Choose a **key password** (Usually the same as keystore password).

This will generate a file named `my-release-key.jks` in your current directory.

---

## Step 2: Configure Gradle

1. Move the generated `my-release-key.jks` file to your Flutter project's `android/app` folder.
2. Create a file named `key.properties` inside the `android/` folder of your project.
3. Add the following contents to `android/key.properties`:

   ```properties
   storePassword=YOUR_KEYSTORE_PASSWORD
   keyPassword=YOUR_KEY_PASSWORD
   keyAlias=my-key-alias
   storeFile=my-release-key.jks
   ```

4. Modify `android/app/build.gradle.kts` to read this properties file and sign release builds automatically.

---

## Step 3: Build the Signed Release

Once configured, build your signed release package using the Flutter CLI:

```bash
# Build a signed Android App Bundle (recommended for Google Play Store upload)
flutter build appbundle

# Or build a signed standalone APK
flutter build apk --release
```

The output will be created in `build/app/outputs/bundle/release/` or `build/app/outputs/flutter-apk/`.
