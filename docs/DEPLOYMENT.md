# Omnispex Deployment & Release Pipelines

This document details the complete build, cross-compilation, packaging, and deployment pipelines for all supported target platforms:
- **Rust CLI** (Windows, Linux, macOS)
- **Flutter Android** (APK and Google Play App Bundle `.aab`)
- **Flutter Web** (WebAssembly SPA / PWA)
- **Desktop** (Windows, Linux, macOS)

---

## 1. Prerequisites & Toolchain Matrix

| Tool / SDK | Minimum Version | Target Purpose |
| :--- | :--- | :--- |
| **Rust Toolchain** | `1.78.0+` (stable) | Core logic, CLI, Native FFI libraries, and WebAssembly |
| **Flutter SDK** | `3.24.0+` (Channel stable) | Cross-platform UI compilation |
| **Android NDK** | `r26d+` (26.3.11579264+) | Compiling `omnispex_flutter` for Android ABIs |
| **cargo-ndk** | `3.5.0+` | Rust NDK cross-compilation helper (`cargo install cargo-ndk`) |
| **wasm32-unknown-unknown** | Target installed via `rustup` | WebAssembly Rust compilation (`rustup target add wasm32-unknown-unknown`) |
| **Java JDK** | OpenJDK 17 or 21 | Android Gradle build pipeline |

---

## 2. Shared Data Asset Pipeline

Before packaging any Flutter platform artifact, the normalized 11th Edition game catalogue must be generated.

### Building the Production Catalogue Bundle
```bash
# Ingest BSData catalogue definitions and MFM points into the production asset bundle
cargo run --release -p omnispex_cli -- build-catalogue-bundle \
  --bsdata-dir ./wh40k-11e \
  --mfm-dir ./wh40k-11e-mfm/data \
  --output ./flutter_ui/assets/data/wh40k_11e_bundle.json
```

**Verification Checklist**:
- Verify file existence: `flutter_ui/assets/data/wh40k_11e_bundle.json`.
- Verify dataset contents via CLI:
  ```bash
  cargo run -p omnispex_cli -- search-units -b flutter_ui/assets/data/wh40k_11e_bundle.json -q "Ghazghkull"
  ```
  Expected: `[Xenos - Orks] Ghazghkull Thraka | 290 pts | M:8" T:10 Sv:2+ W:16 OC:4`.

---

## 3. Rust CLI Deployment Pipeline

The CLI (`crates/omnispex_cli`) is self-contained and statically links `omnispex_core`.

### 3.1 Host Build (Local Platform)
```bash
cargo build --release -p omnispex_cli
```
Binary output location: `target/release/omnispex_cli` (or `omnispex_cli.exe` on Windows).

### 3.2 Cross-Compilation Targets

```bash
# Windows x86_64 (MSVC)
rustup target add x86_64-pc-windows-msvc
cargo build --release --target x86_64-pc-windows-msvc -p omnispex_cli

# Linux x86_64 (GNU)
rustup target add x86_64-unknown-linux-gnu
cargo build --release --target x86_64-unknown-linux-gnu -p omnispex_cli

# Linux x86_64 (musl - fully static standalone binary)
rustup target add x86_64-unknown-linux-musl
cargo build --release --target x86_64-unknown-linux-musl -p omnispex_cli

# macOS x86_64 & Apple Silicon (Universal Binary)
rustup target add x86_64-apple-darwin aarch64-apple-darwin
cargo build --release --target x86_64-apple-darwin -p omnispex_cli
cargo build --release --target aarch64-apple-darwin -p omnispex_cli
lipo -create -output target/release/omnispex_cli \
  target/x86_64-apple-darwin/release/omnispex_cli \
  target/aarch64-apple-darwin/release/omnispex_cli
```

### 3.3 Packaging Standalone Releases
Package the binary together with the reference bundle for out-of-the-box offline evaluation:
```
dist/omnispex-cli-v0.1.0-<platform>/
├── omnispex_cli (or omnispex_cli.exe)
├── data/
│   └── wh40k_11e_bundle.json
└── README.txt
```

---

## 4. Flutter Android Deployment Pipeline

The Android deployment pipeline builds native Rust shared libraries (`.so`) for all target CPU architectures and places them in `jniLibs` prior to running Gradle.

### 4.1 Step 1: Install Rust Android Targets
```bash
rustup target add aarch64-linux-android x86_64-linux-android armv7-linux-androideabi i686-linux-android
cargo install cargo-ndk
```

### 4.2 Step 2: Compile Rust Shared Libraries (`jniLibs`)
Ensure `ANDROID_NDK_HOME` (or `ANDROID_HOME/ndk/<version>`) is set in the environment:
```bash
# From workspace root:
cargo ndk \
  -t arm64-v8a \
  -t x86_64 \
  -o flutter_ui/android/app/src/main/jniLibs \
  build --release -p omnispex_flutter
```
This generates:
- `flutter_ui/android/app/src/main/jniLibs/arm64-v8a/libomnispex_flutter.so`
- `flutter_ui/android/app/src/main/jniLibs/x86_64/libomnispex_flutter.so`

### 4.3 Step 3: Configure Release Signing (Optional / Store Release)
Create `flutter_ui/android/key.properties` (never commit keystores to version control):
```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=/path/to/upload-keystore.jks
```

Verify that `flutter_ui/android/app/build.gradle` references `key.properties`:
```groovy
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    ...
    signingConfigs {
        release {
            if (keystorePropertiesFile.exists()) {
                keyAlias keystoreProperties['keyAlias']
                keyPassword keystoreProperties['keyPassword']
                storeFile file(keystoreProperties['storeFile'])
                storePassword keystoreProperties['storePassword']
            }
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled false
            shrinkResources false
        }
    }
}
```

### 4.4 Step 4: Build Release APK or AAB
```bash
cd flutter_ui

# Option A: Universal APK or per-ABI split APKs (recommended for sideloading & direct distribution)
flutter build apk --release --split-per-abi

# Option B: Google Play Store App Bundle (.aab)
flutter build appbundle --release
```

**Artifact Outputs**:
- Universal APK: `flutter_ui/build/app/outputs/flutter-apk/app-release.apk`
- Per-ABI APKs: `flutter_ui/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- Play Bundle: `flutter_ui/build/app/outputs/bundle/release/app-release.aab`

### 4.5 Step 5: Verification on Physical Device
```bash
# Verify native bridge and offline database on connected Android device
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
adb logcat -s Flutter | grep -E "Omnispex|Bridge"
```

---

## 5. Flutter Web Deployment Pipeline

The web build runs 100% client-side in any modern browser using WebAssembly.

### 5.1 Step 1: Compile Rust Bridge to WebAssembly
```bash
# 1. Add wasm target
rustup target add wasm32-unknown-unknown

# 2. Build release WebAssembly module
cargo build --target wasm32-unknown-unknown --release -p omnispex_flutter

# 3. Copy WebAssembly module to web assets
cp target/wasm32-unknown-unknown/release/omnispex_flutter.wasm flutter_ui/web/omnispex_flutter.wasm
```

*(On Windows PowerShell):*
```powershell
Copy-Item target/wasm32-unknown-unknown/release/omnispex_flutter.wasm flutter_ui/web/omnispex_flutter.wasm -Force
```

### 5.2 Step 2: Build Flutter Web Release
```bash
cd flutter_ui
flutter build web --release --base-href /
```

Output directory: `flutter_ui/build/web/`.

### 5.3 Step 3: Web Server & MIME Configuration

For WebAssembly to load securely and quickly, the hosting server must serve `.wasm` with `Content-Type: application/wasm`.

#### Cloudflare Worker & D1 Edge Deployment:
Omnispex deploys its Web SPA and Edge Cloud Sync Gateway via Cloudflare Workers and Cloudflare D1:
- **Live Production URL**: `https://omnispex-cloud.kamilsuhak.workers.dev`
- **Configuration**: [`services/cloud-worker/wrangler.toml`](../services/cloud-worker/wrangler.toml)
- **Edge SQLite Database**: Cloudflare D1 `omnispex-db` (`42626453-b94a-4f19-9c7e-7521738890e3`)
- **Direct Deployment**:
  ```bash
  cd services/cloud-worker
  npm install
  npx wrangler deploy
  ```
- **Sync Endpoints**:
  - `GET /api/health` — Edge status & D1 connectivity
  - `GET /api/sync/:userId` — Retrieve user's synced armies & wishlists
  - `POST /api/sync/:userId` — Upsert user's synced data
  - `GET|POST|DELETE /api/rosters/:userId` — Manage cloud rosters
  - `GET|POST /api/wishlists/:userId` — Manage faction wishlists

#### NGINX Configuration (Alternative Self-Hosted Server):
```nginx
server {
    listen 80;
    server_name omnispex.app;
    root /var/www/omnispex/build/web;
    index index.html;

    types {
        application/wasm wasm;
        application/javascript js;
        application/json json;
        text/html html;
        text/css css;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }

    # Enable compression for faster catalogue asset delivery
    gzip on;
    gzip_types application/javascript application/json application/wasm text/css text/plain;
}
```

#### Cloudflare Pages / GitHub Pages:
- Push `flutter_ui/build/web` to the designated deployment branch (e.g. `gh-pages`).
- Both providers automatically serve `application/wasm` headers and support HTTPS.

---

## 6. Desktop Deployment Pipeline (Windows / Linux / macOS)

Omnispex supports desktop execution with native dynamic link libraries.

### 6.1 Windows Build
```bash
# 1. Compile native DLL
cargo build --release -p omnispex_flutter
cp target/release/omnispex_flutter.dll flutter_ui/

# 2. Build Flutter Windows executable
cd flutter_ui
flutter build windows --release
```
Distribution artifact: `flutter_ui/build/windows/x64/runner/Release/`.

### 6.2 Linux Build
```bash
# 1. Compile native shared object
cargo build --release -p omnispex_flutter
cp target/release/libomnispex_flutter.so flutter_ui/

# 2. Build Flutter Linux executable
cd flutter_ui
flutter build linux --release
```
Distribution artifact: `flutter_ui/build/linux/x64/release/bundle/`.

### 6.3 macOS Build
```bash
# 1. Compile native dynamic library
cargo build --release -p omnispex_flutter
cp target/release/libomnispex_flutter.dylib flutter_ui/

# 2. Build Flutter macOS application
cd flutter_ui
flutter build macos --release
```
Distribution artifact: `flutter_ui/build/macos/Build/Products/Release/omnispex.app`.

---

## 7. Automated CI/CD Workflow (GitHub Actions)

Below is the recommended multi-platform build workflow (`.github/workflows/deploy.yml`):

```yaml
name: Omnispex Multi-Platform Build & Verification

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  rust-tests:
    name: Rust Core & CLI Verification
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      - name: Run Workspace Tests
        run: cargo test --workspace

  build-cli:
    name: Build Multi-Platform CLI
    needs: rust-tests
    strategy:
      matrix:
        include:
          - target: x86_64-unknown-linux-gnu
            os: ubuntu-latest
            bin: omnispex_cli
          - target: x86_64-pc-windows-msvc
            os: windows-latest
            bin: omnispex_cli.exe
          - target: aarch64-apple-darwin
            os: macos-latest
            bin: omnispex_cli
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with:
          targets: ${{ matrix.target }}
      - name: Build Release Binary
        run: cargo build --release --target ${{ matrix.target }} -p omnispex_cli
      - uses: actions/upload-artifact@v4
        with:
          name: cli-${{ matrix.target }}
          path: target/${{ matrix.target }}/release/${{ matrix.bin }}

  build-web:
    name: Build Flutter Web (WASM)
    needs: rust-tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with:
          targets: wasm32-unknown-unknown
      - uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
          cache: true
      - name: Compile Rust WebAssembly Module
        run: |
          cargo build --target wasm32-unknown-unknown --release -p omnispex_flutter
          cp target/wasm32-unknown-unknown/release/omnispex_flutter.wasm flutter_ui/web/
      - name: Analyze & Build Flutter Web
        run: |
          cd flutter_ui
          flutter pub get
          flutter analyze
          flutter build web --release --base-href /
      - uses: actions/upload-artifact@v4
        with:
          name: flutter-web-bundle
          path: flutter_ui/build/web/

  build-android:
    name: Build Android APK
    needs: rust-tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with:
          targets: aarch64-linux-android, x86_64-linux-android
      - uses: nttld/setup-ndk@v1
        with:
          ndk-version: r26d
      - uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
          cache: true
      - name: Install cargo-ndk
        run: cargo install cargo-ndk
      - name: Build Android JNI Libraries
        run: |
          cargo ndk -t arm64-v8a -t x86_64 -o flutter_ui/android/app/src/main/jniLibs build --release -p omnispex_flutter
      - name: Build APK
        run: |
          cd flutter_ui
          flutter pub get
          flutter build apk --release --split-per-abi
      - uses: actions/upload-artifact@v4
        with:
          name: android-release-apks
          path: flutter_ui/build/app/outputs/flutter-apk/*.apk
```

---

## 8. Release Verification Checklist

Prior to distributing any release:
- [ ] Run `cargo test --workspace` (All 41 integration tests passing).
- [ ] Run `cd flutter_ui && flutter analyze` (0 errors).
- [ ] Check catalogue data provenance: Verify edition header and commit hash in `wh40k_11e_bundle.json`.
- [ ] Validate user data isolation: Verify that installing a new version of the app retains existing user lists and match histories (`PersonalDataStore`).
- [ ] Test offline behavior: Verify unit browsing and combat simulations with network connectivity disabled.

