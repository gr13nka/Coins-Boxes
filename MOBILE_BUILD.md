# Mobile Build Instructions

Guide for building Coins-Boxes for Android and iOS.

## Prerequisites

Your game is already configured for mobile:
- Touch input handling in `main.lua`
- Haptic feedback via `mobile.lua`
- HiDPI enabled in `conf.lua`
- Auto-fullscreen on mobile devices
- Portrait orientation (1080x2400 virtual canvas)

---

## Android Build

### Option A: love-android (Recommended)

**Requirements:**
- Java JDK 17+
- Android SDK (via Android Studio or standalone)
- Git

**Steps:**

1. **Clone love-android:**
   ```bash
   git clone --recursive https://github.com/love2d/love-android.git
   cd love-android
   ```

2. **Copy your game files:**
   ```bash
   # Copy all .lua files and assets to embed folder
   cp -r /path/to/Coins-Boxes/* app/src/embed/assets/
   ```

   Files to include:
   - All `.lua` files (main.lua, game.lua, etc.)
   - `assets/` folder
   - `sfx/` folder
   - `bgnd_music/` folder
   - `comic shanns.otf` font

3. **Configure AndroidManifest.xml:**

   Edit `app/src/main/AndroidManifest.xml`:
   ```xml
   <!-- Find the <activity> tag and add/modify: -->
   android:screenOrientation="portrait"
   ```

4. **Configure app name and package:**

   Edit `app/build.gradle`:
   ```gradle
   android {
       namespace "com.yourname.coinsboxes"
       defaultConfig {
           applicationId "com.yourname.coinsboxes"
           versionCode 1
           versionName "1.0"
       }
   }
   ```

   Edit `app/src/main/res/values/strings.xml`:
   ```xml
   <string name="app_name">Coins &amp; Boxes</string>
   ```

5. **Build the APK:**
   ```bash
   # Debug build (for testing)
   ./gradlew assembleDebug

   # Release build (for distribution)
   ./gradlew assembleRelease
   ```

   APK location: `app/build/outputs/apk/`

6. **Install on device:**
   ```bash
   adb install app/build/outputs/apk/debug/app-debug.apk
   ```

### Option B: Create .love file + APK Builder

1. **Create .love file:**
   ```bash
   cd /path/to/Coins-Boxes
   zip -r CoinsBoxes.love . -x "*.git*" -x "MOBILE_BUILD.md" -x "*.md"
   ```

2. **Use online builder:**
   - https://lovebrew.org/ (web-based)
   - Or download a LÖVE APK template and merge

---

## iOS Build

**Requirements:**
- macOS computer
- Xcode 14+ (free from App Store)
- Apple Developer account ($99/year for App Store distribution, free for personal device testing)

**Steps:**

1. **Clone love-ios:**
   ```bash
   git clone --recursive https://github.com/love2d/love-ios.git
   cd love-ios
   ```

2. **Open in Xcode:**
   ```bash
   open platform/xcode/love.xcodeproj
   ```

3. **Add game files:**
   - In Xcode, right-click on the project
   - Select "Add Files to love..."
   - Navigate to your Coins-Boxes folder
   - Select all `.lua` files and asset folders
   - Check "Copy items if needed"
   - Check "Create folder references" for asset folders

4. **Configure project settings:**

   Select the "love-ios" target, then:

   **General tab:**
   - Display Name: `Coins & Boxes`
   - Bundle Identifier: `com.yourname.coinsboxes`
   - Version: `1.0`
   - Build: `1`

   **Signing & Capabilities:**
   - Team: Select your Apple Developer account
   - Signing Certificate: Auto or your certificate

   **Info tab (or Info.plist):**
   - Add/modify: `UISupportedInterfaceOrientations` → Portrait only
   - Remove landscape orientations

5. **Set orientation in Info.plist:**
   ```xml
   <key>UISupportedInterfaceOrientations</key>
   <array>
       <string>UIInterfaceOrientationPortrait</string>
   </array>
   <key>UISupportedInterfaceOrientations~ipad</key>
   <array>
       <string>UIInterfaceOrientationPortrait</string>
   </array>
   ```

6. **Build and run:**
   - Connect your iOS device via USB
   - Select your device in the scheme dropdown
   - Press Cmd+R to build and run
   - First time: Trust the developer in Settings > General > Device Management

7. **Archive for App Store (optional):**
   - Product > Archive
   - Distribute App > App Store Connect

---

## Troubleshooting

### Android

**"SDK location not found":**
Create `local.properties` in love-android root:
```
sdk.dir=/path/to/Android/Sdk
```

**Gradle version issues:**
```bash
./gradlew wrapper --gradle-version=8.0
```

**APK won't install:**
- Enable "Install from unknown sources" in device settings
- Uninstall old version first: `adb uninstall com.yourname.coinsboxes`

### iOS

**"Signing requires a development team":**
- Sign in to Xcode with Apple ID: Xcode > Preferences > Accounts
- Select team in project settings

**Device not recognized:**
- Trust computer on device
- Try different USB cable/port

**"App could not be installed":**
- Clean build: Cmd+Shift+K
- Delete app from device, reinstall

---

## App Store / Play Store Checklist

### Google Play Store
- [ ] App icon (512x512 PNG)
- [ ] Feature graphic (1024x500 PNG)
- [ ] Screenshots (phone + tablet)
- [ ] Privacy policy URL
- [ ] Content rating questionnaire
- [ ] Signed release APK/AAB

### Apple App Store
- [ ] App icon (1024x1024 PNG, no transparency)
- [ ] Screenshots for all device sizes
- [ ] App preview video (optional)
- [ ] Privacy policy URL
- [ ] App Store description
- [ ] Keywords

---

## Game-Specific Notes

- Virtual canvas: 1080x2400 (portrait)
- Touch targets are sized appropriately
- Haptic feedback enabled for:
  - Coin pickup (0.02s vibration)
  - Coin drop (0.04s vibration)
  - Merge (0.08s vibration)
  - Invalid placement error (0.03s vibration)
- Sound toggle buttons: 80x80px (touch-friendly)
- Auto-fullscreen on mobile devices

---

## Useful Links

- LÖVE for Android: https://github.com/love2d/love-android
- LÖVE for iOS: https://github.com/love2d/love-ios
- LÖVE Wiki Mobile: https://love2d.org/wiki/Getting_Started#Mobile_platforms
- Android Studio: https://developer.android.com/studio
- Xcode: https://developer.apple.com/xcode/
