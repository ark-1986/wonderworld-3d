# WonderWorld 3D — Upload to GitHub and build a native APK

This package contains SOURCE CODE, not an APK. The Android APK has not been compiled or phone-tested.

## Upload source files to your existing repository

Target: https://github.com/ark-1986/wonderworld-3d

1. Download and extract this ZIP on a desktop computer.
2. Open the repository in a browser and choose Add file > Upload files.
3. Upload the **contents** of this folder, keeping folder paths intact. Make sure the hidden `.github/workflows/android-debug-apk.yml` file is included.
4. Commit to the `main` branch. Do NOT upload the ZIP as a single GitHub file; GitHub Actions needs the extracted source files.
5. Go to the repo's Actions tab and choose `Build WonderWorld 3D Android APK` > `Run workflow` if it did not start automatically.
6. If it succeeds, download the `WonderWorld3D-Android-debug-APK` artifact from the run summary, unzip, and install the APK on your own test phone.
7. An actual multiplayer server still needs to be deployed; see README.md and QUICK_START_ROMAN_URDU.md. Offline practice is intended to work without a server.

**Important:** The included workflow is not yet verified on GitHub. The first run may fail and need adjustments; a successful run must be confirmed before calling the APK ready.
