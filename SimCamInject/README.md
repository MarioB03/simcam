# SimCamInject

An injection dylib for the iOS Simulator. It makes an iOS app's barcode/QR scanner **work in the Simulator with no real camera and no changes to the app**.
The dylib intercepts AVFoundation through Objective-C swizzling, draws real frames into the preview layer and delivers the decoded codes to the app's delegate, all from outside the app.

---

## What it does

| Component | Role |
|---|---|
| **SimCamHost / SimCamProbe** | macOS process. It captures the desktop region behind the Simulator window, decodes QR codes and barcodes with Vision, and serves the results over HTTP on `127.0.0.1:8474`. |
| **`/stream`** | MJPEG stream of the captured frames, used for the in-app preview. |
| **`/codes`** | Server-Sent Events stream. It sends one `{"type","stringValue"}` JSON object for each detected code. |
| **SimCamInject.dylib** | Injected into the target app through `DYLD_INSERT_LIBRARIES`. It swizzles `AVCaptureSession` and `AVCaptureMetadataOutput` so the scanner works in the Simulator with no real camera. |

The dylib is **Simulator only** (`iphonesimulator` slice). On a real device, the app uses the physical camera and the dylib isn't injected.

---

## Requirements

- A booted Simulator (`xcrun simctl bootstatus <UDID> -b`).
- **Screen Recording permission** for the terminal (or `swift`), granted in System Settings → Privacy & Security.
- `xcodegen` installed (`brew install xcodegen`).

---

## Supported code types

The common `AVCaptureMetadataOutput` types:

`.qr`, `.code128`, `.ean8`, `.ean13`, `.upce`, `.code39`

The host decodes these types with Vision on the Mac. Vision barcode detection **doesn't work inside the Simulator** on iOS 26.x, which is why decoding happens on the Mac.

---

## Using the GUI app (recommended)

The easiest way to use SimCam is the **SimCam Host** app. It's a signed macOS app with a fixed bundle id (`com.simcam.host`). Because the bundle id is stable, you grant the **Screen Recording** permission once and it survives rebuilds and restarts.

### 1. Build and bundle the app

```bash
# from the repo root
./scripts/build-simcam-host-app.sh
```

This builds `SimCamHost` in release mode, assembles the bundle at `~/Applications/SimCam Host.app` and signs it. You only need to run it again if you change the host's source code.

> Ad-hoc signing can lose the TCC permission. To use a stable signing identity instead, export it before running the script:
> ```bash
> export SIMCAM_SIGN_IDENTITY="Apple Development: Your Name"
> ./scripts/build-simcam-host-app.sh
> ```

### 2. Grant Screen Recording (first run only)

1. Open `~/Applications/SimCam Host.app`.
2. Go to **System Settings → Privacy & Security → Screen Recording**.
3. Turn on **SimCam Host** in the list.
4. Quit and reopen the app.

From then on, the permission is tied to the `com.simcam.host` bundle id and **isn't lost when you rebuild**.

### 3. GUI workflow

The app's UI is in Spanish. Button labels are quoted as they appear.

1. Press **Capturar** (Capture). The status turns green and the fps counter rises above 0.
2. Choose the iOS app you want to test:
   - **An app installed in the Simulator**: select it from the list.
   - **An Xcode project**: enter the path to the `.xcodeproj`/`.xcworkspace` and pick the scheme. The host builds and installs it automatically.
3. Press **Lanzar con SimCam** (Launch with SimCam). SimCam injects the dylib and opens the app with the simulated camera active.
4. Open the scanner in the iOS app. You'll see the live preview and the detected codes.

---

## Headless use (SimCamProbe, for debugging and CI)

`SimCamProbe` is the command-line variant, for debugging or CI where there's no GUI. The Screen Recording permission must be granted to the terminal or process that runs it. This can be fragile on CI without extra setup.

### 1. Start the host

```bash
cd SimCamHost
swift run SimCamProbe
```

The host prints:

```
PROBE: sirviendo en http://127.0.0.1:8474/stream
```

(The log message is in Spanish. It means "serving at".) If the system asks for Screen Recording permission, grant it and run the command again.

### 2. Put the code under the Simulator window

Open the image of the QR code or label on the Mac (Finder, Preview, a browser…) and drag the **Simulator window over** the code. The host captures exactly that region of the desktop, as if the Simulator were transparent.

### 3. Launch the app with the dylib injected

Build the dylib (see below). Then launch the app, already installed in the Simulator, with the dylib injected:

```bash
DYLIB="$PWD/SimCamInject/.build-xcode/Build/Products/Debug-iphonesimulator/SimCamInject.dylib"
SIMCTL_CHILD_DYLD_INSERT_LIBRARIES="$DYLIB" \
  xcrun simctl launch <UDID> <bundle-id>
```

> **IMPORTANT:** the dylib path must be **absolute**. dyld silently ignores a relative path, and the injection doesn't happen.

Open the scanner in the app. You'll see a live preview of whatever is behind the Simulator, and the scan fires automatically once the code is centred.

---

## Verifying the injection

```bash
xcrun simctl spawn <UDID> log show \
  --last 2m \
  --predicate 'eventMessage CONTAINS "[SimCamInject]"' \
  --style compact
```

A successful injection logs lines like these at launch and when the scanner opens. The log messages are in Spanish; the translation of each one follows the `←`.

```
[SimCamInject] dylib cargada (pid=40996)                       ← dylib loaded
[SimCamInject] shims AVFoundation instalados                   ← AVFoundation shims installed
[SimCamInject] preview layer enganchada                        ← preview layer hooked
[SimCamInject] AVCaptureDevice.default(for:) -> fake
[SimCamInject] metadataOutput capturado                        ← metadataOutput captured
[SimCamInject] delegate capturado: <YourApp.BarcodeScannerViewController: 0x...>
[SimCamInject] entregado código (captureOutput:) type=org.gs1.EAN-13 value=1234567890128
                                                               ← code delivered
```

The selector delivered to the delegate is `captureOutput:didOutputMetadataObjects:fromConnection:` (Swift: `metadataOutput(_:didOutput:from:)`).

---

## Dylib internals

| File | Responsibility |
|---|---|
| `SimCamInject.m` | `+load` entry point. Starts the swizzling. |
| `AVFoundationShims.m` | Swizzles `AVCaptureSession` and `AVCaptureDevice`. |
| `CameraFeedShims.m` | Frame-feed mode. It delivers the host's real frames through `AVCaptureVideoDataOutput`, so the app runs its own Vision/ML logic on them. |
| `PreviewLayerShim.m` | Pushes MJPEG frames into `AVCaptureVideoPreviewLayer`. |
| `PreviewClient.m/.h` | MJPEG client that consumes `/stream`. |
| `CodeStreamClient.m/.h` | SSE client that consumes `/codes`. |
| `SimCamDelivery.m/.h` | Builds synthetic `AVMetadataObject`s and delivers them to the delegate. |
| `SimCamMetadataObject.m/.h` | Subclass of `AVMetadataMachineReadableCodeObject`, compiled without ARC. |
| `SimCamBridge.m/.h` | Coordinates the preview and code delivery. |

The dylib is built with XcodeGen (`project.yml`, `library.dynamic`, `iphonesimulator` slice). The product is named `SimCamInject.dylib`, with no `lib` prefix.

---

## Building the dylib manually

```bash
cd SimCamInject
xcodegen          # regenerates SimCamInject.xcodeproj
xcodebuild \
  -project SimCamInject.xcodeproj \
  -scheme SimCamInject \
  -sdk iphonesimulator \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build-xcode \
  build
# dylib at: .build-xcode/Build/Products/Debug-iphonesimulator/SimCamInject.dylib
```

---

## Known limitations (MVP)

- **Process-wide swizzling.** `method_setImplementation` replaces the implementation for *every* instance in the process. The dylib assumes **a single active capture session** (the app's scanner). If the injected app used AVFoundation for anything else, it would get the fake shims too. That includes another `AVCaptureSession`, `AVCaptureVideoPreviewLayer` or `AVCaptureDevice.default(for:)`.
- **Network clients start in `+load`.** `CodeStreamClient` and `PreviewClient` connect to `127.0.0.1:8474` as soon as the dylib loads. They retry every second for the whole life of the process, even if the scanner is never opened.
- **No detection box is drawn.** The synthetic metadata object returns empty `corners`, so the app won't animate a box over the code. **Code delivery is not affected.**
- **Simulator only, debug only.** The dylib is built for the `iphonesimulator` slice and injected manually. On a device, the app uses its real camera, untouched.
